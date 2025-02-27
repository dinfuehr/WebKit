const testCredentialIdBase64 = "SMSXHngF7hEOsElA73C3RY+8bR4=";
const testES256PrivateKeyBase64 =
    "BDj/zxSkzKgaBuS3cdWDF558of8AaIpgFpsjF/Qm1749VBJPgqUIwfhWHJ91nb7U" +
    "PH76c0+WFOzZKslPyyFse4goGIW2R7k9VHLPEZl5nfnBgEVFh5zev+/xpHQIvuq6" +
    "RQ==";
const testES256PublicKeyBase64 =
    "BDj/zxSkzKgaBuS3cdWDF558of8AaIpgFpsjF/Qm1749VBJPgqUIwfhWHJ91nb7U" +
    "PH76c0+WFOzZKslPyyFse4g=";
const testRpId = "localhost";
const testUserhandleBase64 = "AAECAwQFBgcICQ==";
const testAttestationCertificateBase64 =
    "MIIB6jCCAZCgAwIBAgIGAWHAxcjvMAoGCCqGSM49BAMCMFMxJzAlBgNVBAMMHkJh" +
    "c2ljIEF0dGVzdGF0aW9uIFVzZXIgU3ViIENBMTETMBEGA1UECgwKQXBwbGUgSW5j" +
    "LjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0xODAyMjMwMzM3MjJaFw0xODAyMjQw" +
    "MzQ3MjJaMGoxIjAgBgNVBAMMGTAwMDA4MDEwLTAwMEE0OUEyMzBBMDIxM0ExGjAY" +
    "BgNVBAsMEUJBQSBDZXJ0aWZpY2F0aW9uMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMw" +
    "EQYDVQQIDApDYWxpZm9ybmlhMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEvCje" +
    "Pzr6Sg76XMoHuGabPaG6zjpLFL8Zd8/74Hh5PcL2Zq+o+f7ENXX+7nEXXYt0S8Ux" +
    "5TIRw4hgbfxXQbWLEqM5MDcwDAYDVR0TAQH/BAIwADAOBgNVHQ8BAf8EBAMCBPAw" +
    "FwYJKoZIhvdjZAgCBAowCKEGBAR0ZXN0MAoGCCqGSM49BAMCA0gAMEUCIAlK8A8I" +
    "k43TbvKuYGHZs1DTgpTwmKTBvIUw5bwgZuYnAiEAtuJjDLKbGNJAJFMi5deEBqno" +
    "pBTCqbfbDJccfyQpjnY=";
const testAttestationIssuingCACertificateBase64 =
    "MIICIzCCAaigAwIBAgIIeNjhG9tnDGgwCgYIKoZIzj0EAwIwUzEnMCUGA1UEAwwe" +
    "QmFzaWMgQXR0ZXN0YXRpb24gVXNlciBSb290IENBMRMwEQYDVQQKDApBcHBsZSBJ" +
    "bmMuMRMwEQYDVQQIDApDYWxpZm9ybmlhMB4XDTE3MDQyMDAwNDIwMFoXDTMyMDMy" +
    "MjAwMDAwMFowUzEnMCUGA1UEAwweQmFzaWMgQXR0ZXN0YXRpb24gVXNlciBTdWIg" +
    "Q0ExMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9ybmlhMFkw" +
    "EwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEoSZ/1t9eBAEVp5a8PrXacmbGb8zNC1X3" +
    "StLI9YO6Y0CL7blHmSGmjGWTwD4Q+i0J2BY3+bPHTGRyA9jGB3MSbaNmMGQwEgYD" +
    "VR0TAQH/BAgwBgEB/wIBADAfBgNVHSMEGDAWgBSD5aMhnrB0w/lhkP2XTiMQdqSj" +
    "8jAdBgNVHQ4EFgQU5mWf1DYLTXUdQ9xmOH/uqeNSD80wDgYDVR0PAQH/BAQDAgEG" +
    "MAoGCCqGSM49BAMCA2kAMGYCMQC3M360LLtJS60Z9q3vVjJxMgMcFQ1roGTUcKqv" +
    "W+4hJ4CeJjySXTgq6IEHn/yWab4CMQCm5NnK6SOSK+AqWum9lL87W3E6AA1f2TvJ" +
    "/hgok/34jr93nhS87tOQNdxDS8zyiqw=";

const RESOURCES_DIR = "/WebKit/webauthn/resources/";

function asciiToUint8Array(str)
{
    var chars = [];
    for (var i = 0; i < str.length; ++i)
        chars.push(str.charCodeAt(i));
    return new Uint8Array(chars);
}

// Builds a hex string representation for an array-like input.
// "bytes" can be an Array of bytes, an ArrayBuffer, or any TypedArray.
// The output looks like this:
//    ab034c99
function bytesToHexString(bytes)
{
    if (!bytes)
        return null;

    bytes = new Uint8Array(bytes);
    var hexBytes = [];

    for (var i = 0; i < bytes.length; ++i) {
        var byteString = bytes[i].toString(16);
        if (byteString.length < 2)
            byteString = "0" + byteString;
        hexBytes.push(byteString);
    }

    return hexBytes.join("");
}

function bytesToASCIIString(bytes)
{
    return String.fromCharCode.apply(null, new Uint8Array(bytes));
}

var Base64URL = {
    stringify: function (a) {
        var base64string = btoa(String.fromCharCode.apply(0, a));
        return base64string.replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
    },
    parse: function (s) {
        s = s.replace(/-/g, "+").replace(/_/g, "/").replace(/\s/g, '');
        return new Uint8Array(Array.prototype.map.call(atob(s), function (c) { return c.charCodeAt(0) }));
    }
};

function hexStringToUint8Array(hexString)
{
    if (hexString.length % 2 != 0)
        throw "Invalid hexString";
    var arrayBuffer = new Uint8Array(hexString.length / 2);

    for (var i = 0; i < hexString.length; i += 2) {
        var byteValue = parseInt(hexString.substr(i, 2), 16);
        if (byteValue == NaN)
            throw "Invalid hexString";
        arrayBuffer[i/2] = byteValue;
    }

    return arrayBuffer;
}

function decodeAuthData(authDataUint8Array)
{
    let authDataObject = { };
    let pos = 0;
    let size = 0;

    // RP ID Hash
    size = 32;
    if (pos + size > authDataUint8Array.byteLength)
        return { };
    authDataObject.rpIdHash = authDataUint8Array.slice(pos, pos + size);
    pos = pos + size;

    // FLAGS
    size = 1;
    if (pos + size > authDataUint8Array.byteLength)
        return { };
    authDataObject.flags = authDataUint8Array.slice(pos, pos + size)[0];
    pos = pos + size;

    // Counter
    size = 4;
    if (pos + size > authDataUint8Array.byteLength)
        return { };
    authDataObject.counter = new Uint32Array(authDataUint8Array.slice(pos, pos + size))[0];
    pos = pos + size;

    if (pos == authDataUint8Array.byteLength)
        return authDataObject;

    // AAGUID
    size = 16;
    if (pos + size > authDataUint8Array.byteLength)
        return { };
    authDataObject.aaguid = authDataUint8Array.slice(pos, pos + size);
    pos = pos + size;

    // L
    size = 2;
    if (pos + size > authDataUint8Array.byteLength)
        return { };
    // Little Endian
    authDataObject.l = new Uint16Array(authDataUint8Array.slice(pos, pos + size))[0];
    pos = pos + size;

    // Credential ID
    size = authDataObject.l;
    if (pos + size > authDataUint8Array.byteLength)
        return { };
    authDataObject.credentialID = authDataUint8Array.slice(pos, pos + size);
    pos = pos + size;

    // Public Key
    authDataObject.publicKey = CBOR.decode(authDataUint8Array.slice(pos).buffer);
    if (!authDataObject.publicKey)
        return { };

    // Assume no extensions.
    return authDataObject;
}

function concatenateBuffers(buffer1, buffer2)
{
    let tmp = new Uint8Array(buffer1.byteLength + buffer2.byteLength);
    tmp.set(new Uint8Array(buffer1), 0);
    tmp.set(new Uint8Array(buffer2), buffer1.byteLength);
    return tmp.buffer;
}

// Very dirty asn1 decoder. Just works.
function extractRawSignature(asn1signature)
{
    const signature = new Uint8Array(asn1signature);
    let tmp = new Uint8Array(64);

    const rStart =  signature[3] - 32;
    if (rStart >= 0)
        tmp.set(new Uint8Array(signature.slice(4 + rStart, 36 + rStart)), 0);
    else
        tmp.set(new Uint8Array(signature.slice(4, 36 + rStart)), -rStart);

    const sStart =  signature[37 + rStart] - 32;
    if (sStart >= 0)
        tmp.set(new Uint8Array(signature.slice(38 + rStart + sStart)), 32);
    else
        tmp.set(new Uint8Array(signature.slice(38 + rStart)), 32 - sStart);

    return tmp.buffer;
}

function waitForLoad()
{
    return new Promise((resolve) => {
        window.addEventListener('message', (message) => {
            resolve(message);
        });
    });
}

function withCrossOriginIframe(resourceFile)
{
    return new Promise((resolve) => {
        waitForLoad().then((message) => {
            resolve(message);
        });
        const frame = document.createElement("iframe");
        frame.src = get_host_info().HTTPS_REMOTE_ORIGIN + RESOURCES_DIR + resourceFile;
        document.body.appendChild(frame);
    });
}

function promiseRejects(test, expected, promise, description)
{
    return promise.then(test.unreached_func("Should have rejected: " + description)).catch(function(e) {
        assert_throws(expected, function() { throw e }, description);
        assert_equals(e.message, description);
    });
}

// COSE Key Format: https://www.w3.org/TR/webauthn/#sctn-encoded-credPubKey-examples.
function checkPublicKey(publicKey)
{
    if (publicKey['1'] != 2)
        return false;
    if (publicKey['3'] != -7)
        return false;
    if (publicKey['-1'] != 1)
        return false;
    if (publicKey['-2'].byteLength != 32)
        return false;
    if (publicKey['-3'].byteLength != 32)
        return false;
    return true;
}
