/*
 * Copyright (C) 2010-2018 Apple Inc. All rights reserved.
 * Copyright (C) 2013 Company 100 Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "config.h"
#import "WebCoreArgumentCoders.h"

#import "ArgumentCodersCF.h"
#import "DataReference.h"
#import <WebCore/CertificateInfo.h>
#import <WebCore/ContentFilterUnblockHandler.h>
#import <WebCore/Credential.h>
#import <WebCore/KeyboardEvent.h>
#import <WebCore/ProtectionSpace.h>
#import <WebCore/ResourceError.h>
#import <WebCore/ResourceRequest.h>
#import <pal/spi/cf/CFNetworkSPI.h>
#import <pal/spi/cocoa/NSKeyedArchiverSPI.h>
#import <wtf/MachSendRight.h>

#if ENABLE(WIRELESS_PLAYBACK_TARGET)
#import <WebCore/MediaPlaybackTargetContext.h>
#import <objc/runtime.h>
#import <pal/spi/mac/AVFoundationSPI.h>
#import <wtf/SoftLinking.h>

SOFT_LINK_FRAMEWORK_OPTIONAL(AVFoundation)
SOFT_LINK_CLASS(AVFoundation, AVOutputContext)
#endif

namespace IPC {

static RetainPtr<CFMutableDictionaryRef> createSerializableRepresentation(CFIndex version, CFTypeRef* objects, CFIndex objectCount, CFDictionaryRef protocolProperties, CFNumberRef expectedContentLength, CFStringRef mimeType, CFTypeRef tokenNull)
{
    auto archiveListArray = adoptCF(CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks));

    for (CFIndex i = 0; i < objectCount; ++i) {
        CFTypeRef object = objects[i];
        if (object) {
            CFArrayAppendValue(archiveListArray.get(), object);
            CFRelease(object);
        } else {
            // Append our token null representation.
            CFArrayAppendValue(archiveListArray.get(), tokenNull);
        }
    }

    auto dictionary = adoptCF(CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks));

    auto versionNumber = adoptCF(CFNumberCreate(kCFAllocatorDefault, kCFNumberCFIndexType, &version));
    CFDictionarySetValue(dictionary.get(), CFSTR("version"), versionNumber.get());
    CFDictionarySetValue(dictionary.get(), CFSTR("archiveList"), archiveListArray.get());

    if (protocolProperties) {
        CFDictionarySetValue(dictionary.get(), CFSTR("protocolProperties"), protocolProperties);
        CFRelease(protocolProperties);
    }

    if (expectedContentLength) {
        CFDictionarySetValue(dictionary.get(), CFSTR("expectedContentLength"), expectedContentLength);
        CFRelease(expectedContentLength);
    }

    if (mimeType) {
        CFDictionarySetValue(dictionary.get(), CFSTR("mimeType"), mimeType);
        CFRelease(mimeType);
    }

    CFAllocatorDeallocate(kCFAllocatorDefault, objects);

    return dictionary;
}

static CFTypeRef dictionaryValueOfType(CFDictionaryRef dictionary, CFStringRef key, CFTypeID type)
{
    CFTypeRef value = CFDictionaryGetValue(dictionary, key);
    if (value && CFGetTypeID(value) == type)
        return value;
    return nullptr;
}

static bool createArchiveList(CFDictionaryRef representation, CFTypeRef tokenNull, CFIndex* version, CFTypeRef** objects, CFIndex* objectCount, CFDictionaryRef* protocolProperties, CFNumberRef* expectedContentLength, CFStringRef* mimeType)
{
    CFNumberRef versionNumber = (CFNumberRef)dictionaryValueOfType(representation, CFSTR("version"), CFNumberGetTypeID());
    if (!versionNumber)
        return false;

    if (!CFNumberGetValue(versionNumber, kCFNumberCFIndexType, version))
        return false;

    CFArrayRef archiveListArray = (CFArrayRef)dictionaryValueOfType(representation, CFSTR("archiveList"), CFArrayGetTypeID());
    if (!archiveListArray)
        return false;

    *objectCount = CFArrayGetCount(archiveListArray);
    *objects = (CFTypeRef*)malloc(sizeof(CFTypeRef) * *objectCount);
    for (CFIndex i = 0; i < *objectCount; ++i) {
        CFTypeRef object = CFArrayGetValueAtIndex(archiveListArray, i);
        if (object == tokenNull)
            (*objects)[i] = nullptr;
        else
            (*objects)[i] = object;
    }

    if (protocolProperties)
        *protocolProperties = (CFDictionaryRef)dictionaryValueOfType(representation, CFSTR("protocolProperties"), CFDictionaryGetTypeID());

    if (expectedContentLength)
        *expectedContentLength = (CFNumberRef)dictionaryValueOfType(representation, CFSTR("expectedContentLength"), CFNumberGetTypeID());

    if (mimeType)
        *mimeType = (CFStringRef)dictionaryValueOfType(representation, CFSTR("mimeType"), CFStringGetTypeID());

    return true;
}

static RetainPtr<CFDictionaryRef> createSerializableRepresentation(CFURLRequestRef cfRequest, CFTypeRef tokenNull)
{
    CFIndex version;
    CFTypeRef* objects;
    CFIndex objectCount;
    CFDictionaryRef protocolProperties;

    // FIXME (12889518): Do not serialize HTTP message body.
    // 1. It can be large and thus costly to send across.
    // 2. It is misleading to provide a body with some requests, while others use body streams, which cannot be serialized at all.

    _CFURLRequestCreateArchiveList(kCFAllocatorDefault, cfRequest, &version, &objects, &objectCount, &protocolProperties);

    // This will deallocate the passed in arguments.
    return createSerializableRepresentation(version, objects, objectCount, protocolProperties, nullptr, nullptr, tokenNull);
}

static RetainPtr<CFURLRequestRef> createCFURLRequestFromSerializableRepresentation(CFDictionaryRef representation, CFTypeRef tokenNull)
{
    CFIndex version;
    CFTypeRef* objects;
    CFIndex objectCount;
    CFDictionaryRef protocolProperties;

    if (!createArchiveList(representation, tokenNull, &version, &objects, &objectCount, &protocolProperties, nullptr, nullptr))
        return nullptr;

    auto cfRequest = adoptCF(_CFURLRequestCreateFromArchiveList(kCFAllocatorDefault, version, objects, objectCount, protocolProperties));
    free(objects);
    return WTFMove(cfRequest);
}

static RetainPtr<CFDictionaryRef> createSerializableRepresentation(NSURLRequest *request, CFTypeRef tokenNull)
{
    return createSerializableRepresentation([request _CFURLRequest], tokenNull);
}

static RetainPtr<NSURLRequest> createNSURLRequestFromSerializableRepresentation(CFDictionaryRef representation, CFTypeRef tokenNull)
{
    auto cfRequest = createCFURLRequestFromSerializableRepresentation(representation, tokenNull);
    if (!cfRequest)
        return nullptr;
    
    return adoptNS([[NSURLRequest alloc] _initWithCFURLRequest:cfRequest.get()]);
}
    
void ArgumentCoder<WebCore::ResourceRequest>::encodePlatformData(Encoder& encoder, const WebCore::ResourceRequest& resourceRequest)
{
    RetainPtr<NSURLRequest> requestToSerialize = resourceRequest.nsURLRequest(WebCore::HTTPBodyUpdatePolicy::DoNotUpdateHTTPBody);

    bool requestIsPresent = requestToSerialize;
    encoder << requestIsPresent;

    if (!requestIsPresent)
        return;

    // We don't send HTTP body over IPC for better performance.
    // Also, it's not always possible to do, as streams can only be created in process that does networking.
    if ([requestToSerialize HTTPBody] || [requestToSerialize HTTPBodyStream]) {
        requestToSerialize = adoptNS([requestToSerialize mutableCopy]);
        [(NSMutableURLRequest *)requestToSerialize setHTTPBody:nil];
        [(NSMutableURLRequest *)requestToSerialize setHTTPBodyStream:nil];
    }

    RetainPtr<CFDictionaryRef> dictionary = createSerializableRepresentation(requestToSerialize.get(), IPC::tokenNullTypeRef());
    IPC::encode(encoder, dictionary.get());

    // The fallback array is part of NSURLRequest, but it is not encoded by WKNSURLRequestCreateSerializableRepresentation.
    encoder << resourceRequest.responseContentDispositionEncodingFallbackArray();
    encoder.encodeEnum(resourceRequest.requester());
    encoder.encodeEnum(resourceRequest.cachePolicy());
}

bool ArgumentCoder<WebCore::ResourceRequest>::decodePlatformData(Decoder& decoder, WebCore::ResourceRequest& resourceRequest)
{
    bool requestIsPresent;
    if (!decoder.decode(requestIsPresent))
        return false;

    if (!requestIsPresent) {
        resourceRequest = WebCore::ResourceRequest();
        return true;
    }

    RetainPtr<CFDictionaryRef> dictionary;
    if (!IPC::decode(decoder, dictionary))
        return false;

    RetainPtr<NSURLRequest> nsURLRequest = createNSURLRequestFromSerializableRepresentation(dictionary.get(), IPC::tokenNullTypeRef());
    if (!nsURLRequest)
        return false;

    resourceRequest = WebCore::ResourceRequest(nsURLRequest.get());
    
    Vector<String> responseContentDispositionEncodingFallbackArray;
    if (!decoder.decode(responseContentDispositionEncodingFallbackArray))
        return false;

    resourceRequest.setResponseContentDispositionEncodingFallbackArray(
        responseContentDispositionEncodingFallbackArray.size() > 0 ? responseContentDispositionEncodingFallbackArray[0] : String(),
        responseContentDispositionEncodingFallbackArray.size() > 1 ? responseContentDispositionEncodingFallbackArray[1] : String(),
        responseContentDispositionEncodingFallbackArray.size() > 2 ? responseContentDispositionEncodingFallbackArray[2] : String()
    );

    WebCore::ResourceRequest::Requester requester;
    if (!decoder.decodeEnum(requester))
        return false;
    resourceRequest.setRequester(requester);

    WebCore::ResourceRequestCachePolicy cachePolicy;
    if (!decoder.decodeEnum(cachePolicy))
        return false;
    resourceRequest.setCachePolicy(cachePolicy);

    return true;
}

void ArgumentCoder<WebCore::CertificateInfo>::encode(Encoder& encoder, const WebCore::CertificateInfo& certificateInfo)
{
    encoder.encodeEnum(certificateInfo.type());

    switch (certificateInfo.type()) {
#if HAVE(SEC_TRUST_SERIALIZATION)
    case WebCore::CertificateInfo::Type::Trust:
        IPC::encode(encoder, certificateInfo.trust());
        break;
#endif
    case WebCore::CertificateInfo::Type::CertificateChain:
        IPC::encode(encoder, certificateInfo.certificateChain());
        break;
    case WebCore::CertificateInfo::Type::None:
        // Do nothing.
        break;
    }
}

bool ArgumentCoder<WebCore::CertificateInfo>::decode(Decoder& decoder, WebCore::CertificateInfo& certificateInfo)
{
    WebCore::CertificateInfo::Type certificateInfoType;
    if (!decoder.decodeEnum(certificateInfoType))
        return false;

    switch (certificateInfoType) {
#if HAVE(SEC_TRUST_SERIALIZATION)
    case WebCore::CertificateInfo::Type::Trust: {
        RetainPtr<SecTrustRef> trust;
        if (!IPC::decode(decoder, trust))
            return false;

        certificateInfo = WebCore::CertificateInfo(WTFMove(trust));
        return true;
    }
#endif
    case WebCore::CertificateInfo::Type::CertificateChain: {
        RetainPtr<CFArrayRef> certificateChain;
        if (!IPC::decode(decoder, certificateChain))
            return false;

        certificateInfo = WebCore::CertificateInfo(WTFMove(certificateChain));
        return true;
    }    
    case WebCore::CertificateInfo::Type::None:
        // Do nothing.
        break;
    }

    return true;
}

static void encodeNSError(Encoder& encoder, NSError *nsError)
{
    String domain = [nsError domain];
    encoder << domain;

    int64_t code = [nsError code];
    encoder << code;

    NSDictionary *userInfo = [nsError userInfo];

    RetainPtr<CFMutableDictionaryRef> filteredUserInfo = adoptCF(CFDictionaryCreateMutable(kCFAllocatorDefault, userInfo.count, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks));

    [userInfo enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL*) {
        if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSURL class]] || [value isKindOfClass:[NSNumber class]])
            CFDictionarySetValue(filteredUserInfo.get(), (__bridge CFTypeRef)key, (__bridge CFTypeRef)value);
    }];

    if (NSArray *clientIdentityAndCertificates = [userInfo objectForKey:@"NSErrorClientCertificateChainKey"]) {
        ASSERT([clientIdentityAndCertificates isKindOfClass:[NSArray class]]);
        ASSERT(^{
            for (id object in clientIdentityAndCertificates) {
                if (CFGetTypeID((__bridge CFTypeRef)object) != SecIdentityGetTypeID() && CFGetTypeID((__bridge CFTypeRef)object) != SecCertificateGetTypeID())
                    return false;
            }
            return true;
        }());

        // Turn SecIdentity members into SecCertificate to strip out private key information.
        id clientCertificates = [NSMutableArray arrayWithCapacity:clientIdentityAndCertificates.count];
        for (id object in clientIdentityAndCertificates) {
            if (CFGetTypeID((__bridge CFTypeRef)object) != SecIdentityGetTypeID()) {
                [clientCertificates addObject:object];
                continue;
            }
            SecCertificateRef certificate = nil;
            OSStatus status = SecIdentityCopyCertificate((SecIdentityRef)object, &certificate);
            RetainPtr<SecCertificateRef> retainCertificate = adoptCF(certificate);
            // The SecIdentity member is the key information of this attribute. Without it, we should nil
            // the attribute.
            if (status != errSecSuccess) {
                LOG_ERROR("Failed to encode nsError.userInfo[NSErrorClientCertificateChainKey]: %d", status);
                clientCertificates = nil;
                break;
            }
            [clientCertificates addObject:(__bridge id)certificate];
        }
        CFDictionarySetValue(filteredUserInfo.get(), CFSTR("NSErrorClientCertificateChainKey"), (__bridge CFTypeRef)clientCertificates);
    }

    id peerCertificateChain = [userInfo objectForKey:@"NSErrorPeerCertificateChainKey"];
    if (!peerCertificateChain) {
        if (SecTrustRef peerTrust = (__bridge SecTrustRef)[userInfo objectForKey:NSURLErrorFailingURLPeerTrustErrorKey]) {
            CFIndex count = SecTrustGetCertificateCount(peerTrust);
            peerCertificateChain = [NSMutableArray arrayWithCapacity:count];
            for (CFIndex i = 0; i < count; ++i)
                [peerCertificateChain addObject:(__bridge id)SecTrustGetCertificateAtIndex(peerTrust, i)];
        }
    }
    ASSERT(!peerCertificateChain || [peerCertificateChain isKindOfClass:[NSArray class]]);
    if (peerCertificateChain)
        CFDictionarySetValue(filteredUserInfo.get(), CFSTR("NSErrorPeerCertificateChainKey"), (__bridge CFTypeRef)peerCertificateChain);

#if HAVE(SEC_TRUST_SERIALIZATION)
    if (SecTrustRef peerTrust = (__bridge SecTrustRef)[userInfo objectForKey:NSURLErrorFailingURLPeerTrustErrorKey])
        CFDictionarySetValue(filteredUserInfo.get(), (__bridge CFStringRef)NSURLErrorFailingURLPeerTrustErrorKey, peerTrust);
#endif

    IPC::encode(encoder, filteredUserInfo.get());

    if (id underlyingError = [userInfo objectForKey:NSUnderlyingErrorKey]) {
        ASSERT([underlyingError isKindOfClass:[NSError class]]);
        encoder << true;
        encodeNSError(encoder, underlyingError);
    } else
        encoder << false;
}

void ArgumentCoder<WebCore::ResourceError>::encodePlatformData(Encoder& encoder, const WebCore::ResourceError& resourceError)
{
    encodeNSError(encoder, resourceError.nsError());
}

static bool decodeNSError(Decoder& decoder, RetainPtr<NSError>& nsError)
{
    String domain;
    if (!decoder.decode(domain))
        return false;

    int64_t code;
    if (!decoder.decode(code))
        return false;

    RetainPtr<CFDictionaryRef> userInfo;
    if (!IPC::decode(decoder, userInfo))
        return false;

    bool hasUnderlyingError = false;
    if (!decoder.decode(hasUnderlyingError))
        return false;

    if (hasUnderlyingError) {
        RetainPtr<NSError> underlyingNSError;
        if (!decodeNSError(decoder, underlyingNSError))
            return false;

        auto mutableUserInfo = adoptCF(CFDictionaryCreateMutableCopy(kCFAllocatorDefault, CFDictionaryGetCount(userInfo.get()) + 1, userInfo.get()));
        CFDictionarySetValue(mutableUserInfo.get(), (__bridge CFStringRef)NSUnderlyingErrorKey, (__bridge CFTypeRef)underlyingNSError.get());
        userInfo = WTFMove(mutableUserInfo);
    }

    nsError = adoptNS([[NSError alloc] initWithDomain:domain code:code userInfo:(__bridge NSDictionary *)userInfo.get()]);
    return true;
}

bool ArgumentCoder<WebCore::ResourceError>::decodePlatformData(Decoder& decoder, WebCore::ResourceError& resourceError)
{
    RetainPtr<NSError> nsError;
    if (!decodeNSError(decoder, nsError))
        return false;

    resourceError = WebCore::ResourceError(nsError.get());
    return true;
}

void ArgumentCoder<WebCore::ProtectionSpace>::encodePlatformData(Encoder& encoder, const WebCore::ProtectionSpace& space)
{
    auto archiver = secureArchiver();
    [archiver encodeObject:space.nsSpace() forKey:@"protectionSpace"];
    IPC::encode(encoder, (__bridge CFDataRef)archiver.get().encodedData);
}

bool ArgumentCoder<WebCore::ProtectionSpace>::decodePlatformData(Decoder& decoder, WebCore::ProtectionSpace& space)
{
    RetainPtr<CFDataRef> data;
    if (!IPC::decode(decoder, data))
        return false;

    auto unarchiver = secureUnarchiverFromData((__bridge NSData *)data.get());
    @try {
        if (RetainPtr<NSURLProtectionSpace> nsSpace = [unarchiver decodeObjectOfClass:[NSURLProtectionSpace class] forKey:@"protectionSpace"])
            space = WebCore::ProtectionSpace(nsSpace.get());
    } @catch (NSException *exception) {
        LOG_ERROR("Failed to decode NSURLProtectionSpace: %@", exception);
    }

    [unarchiver finishDecoding];
    return true;
}

void ArgumentCoder<WebCore::Credential>::encodePlatformData(Encoder& encoder, const WebCore::Credential& credential)
{
    NSURLCredential *nsCredential = credential.nsCredential();
    // NSURLCredential doesn't serialize identities correctly, so we encode the pieces individually
    // in the identity case. See <rdar://problem/18802434>.
    if (SecIdentityRef identity = nsCredential.identity) {
        encoder << true;
        IPC::encode(encoder, identity);

        if (NSArray *certificates = nsCredential.certificates) {
            encoder << true;
            IPC::encode(encoder, (__bridge CFArrayRef)certificates);
        } else
            encoder << false;

        encoder << static_cast<uint64_t>(nsCredential.persistence);
        return;
    }

    encoder << false;

    auto archiver = secureArchiver();
    [archiver encodeObject:nsCredential forKey:@"credential"];
    IPC::encode(encoder, (__bridge CFDataRef)archiver.get().encodedData);
}

bool ArgumentCoder<WebCore::Credential>::decodePlatformData(Decoder& decoder, WebCore::Credential& credential)
{
    bool hasIdentity;
    if (!decoder.decode(hasIdentity))
        return false;

    if (hasIdentity) {
        RetainPtr<SecIdentityRef> identity;
        if (!IPC::decode(decoder, identity))
            return false;

        RetainPtr<CFArrayRef> certificates;
        bool hasCertificates;
        if (!decoder.decode(hasCertificates))
            return false;

        if (hasCertificates) {
            if (!IPC::decode(decoder, certificates))
                return false;
        }

        uint64_t persistence;
        if (!decoder.decode(persistence))
            return false;

        credential = WebCore::Credential(adoptNS([[NSURLCredential alloc] initWithIdentity:identity.get() certificates:(__bridge NSArray *)certificates.get() persistence:(NSURLCredentialPersistence)persistence]).get());
        return true;
    }

    RetainPtr<CFDataRef> data;
    if (!IPC::decode(decoder, data))
        return false;

    auto unarchiver = secureUnarchiverFromData((__bridge NSData *)data.get());
    @try {
        if (RetainPtr<NSURLCredential> nsCredential = [unarchiver decodeObjectOfClass:[NSURLCredential class] forKey:@"credential"])
            credential = WebCore::Credential(nsCredential.get());
    } @catch (NSException *exception) {
        LOG_ERROR("Failed to decode NSURLCredential: %@", exception);
    }

    [unarchiver finishDecoding];
    return true;
}

void ArgumentCoder<MachSendRight>::encode(Encoder& encoder, const MachSendRight& sendRight)
{
    encoder << Attachment(sendRight.copySendRight().leakSendRight(), MACH_MSG_TYPE_MOVE_SEND);
}

void ArgumentCoder<MachSendRight>::encode(Encoder& encoder, MachSendRight&& sendRight)
{
    encoder << Attachment(sendRight.leakSendRight(), MACH_MSG_TYPE_MOVE_SEND);
}

bool ArgumentCoder<MachSendRight>::decode(Decoder& decoder, MachSendRight& sendRight)
{
    Attachment attachment;
    if (!decoder.decode(attachment))
        return false;

    if (attachment.disposition() != MACH_MSG_TYPE_MOVE_SEND)
        return false;

    sendRight = MachSendRight::adopt(attachment.port());
    return true;
}

void ArgumentCoder<WebCore::KeypressCommand>::encode(Encoder& encoder, const WebCore::KeypressCommand& keypressCommand)
{
    encoder << keypressCommand.commandName << keypressCommand.text;
}
    
std::optional<WebCore::KeypressCommand> ArgumentCoder<WebCore::KeypressCommand>::decode(Decoder& decoder)
{
    std::optional<String> commandName;
    decoder >> commandName;
    if (!commandName)
        return std::nullopt;
    
    std::optional<String> text;
    decoder >> text;
    if (!text)
        return std::nullopt;
    
    WebCore::KeypressCommand command;
    command.commandName = WTFMove(*commandName);
    command.text = WTFMove(*text);
    return WTFMove(command);
}

#if ENABLE(CONTENT_FILTERING)

void ArgumentCoder<WebCore::ContentFilterUnblockHandler>::encode(Encoder& encoder, const WebCore::ContentFilterUnblockHandler& contentFilterUnblockHandler)
{
    auto archiver = secureArchiver();
    contentFilterUnblockHandler.encode(archiver.get());
    IPC::encode(encoder, (__bridge CFDataRef)archiver.get().encodedData);
}

bool ArgumentCoder<WebCore::ContentFilterUnblockHandler>::decode(Decoder& decoder, WebCore::ContentFilterUnblockHandler& contentFilterUnblockHandler)
{
    RetainPtr<CFDataRef> data;
    if (!IPC::decode(decoder, data))
        return false;

    auto unarchiver = secureUnarchiverFromData((__bridge NSData *)data.get());
    if (!WebCore::ContentFilterUnblockHandler::decode(unarchiver.get(), contentFilterUnblockHandler))
        return false;

    [unarchiver finishDecoding];
    return true;
}

#endif

#if ENABLE(WIRELESS_PLAYBACK_TARGET)

static NSString *deviceContextKey()
{
    static NSString * const key = @"deviceContext";
    return key;
}

void ArgumentCoder<WebCore::MediaPlaybackTargetContext>::encodePlatformData(Encoder& encoder, const WebCore::MediaPlaybackTargetContext& target)
{
    auto archiver = secureArchiver();

    if ([getAVOutputContextClass() conformsToProtocol:@protocol(NSSecureCoding)])
        [archiver encodeObject:target.avOutputContext() forKey:deviceContextKey()];

    IPC::encode(encoder, (__bridge CFDataRef)archiver.get().encodedData);
}

bool ArgumentCoder<WebCore::MediaPlaybackTargetContext>::decodePlatformData(Decoder& decoder, WebCore::MediaPlaybackTargetContext& target)
{
    if (![getAVOutputContextClass() conformsToProtocol:@protocol(NSSecureCoding)])
        return false;

    RetainPtr<CFDataRef> data;
    if (!IPC::decode(decoder, data))
        return false;

    auto unarchiver = secureUnarchiverFromData((__bridge NSData *)data.get());

    AVOutputContext *context = nil;
    @try {
        context = [unarchiver decodeObjectOfClass:getAVOutputContextClass() forKey:deviceContextKey()];
    } @catch (NSException *exception) {
        LOG_ERROR("The target picker being decoded is not an AVOutputContext.");
        return false;
    }

    target = WebCore::MediaPlaybackTargetContext(context);
    
    [unarchiver finishDecoding];
    return true;
}

#endif

} // namespace IPC
