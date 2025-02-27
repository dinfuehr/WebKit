/*
 * Copyright (C) 2017 Apple Inc. All rights reserved.
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

WI.CanvasOverviewContentView = class CanvasOverviewContentView extends WI.CollectionContentView
{
    constructor(representedObject)
    {
        console.assert(representedObject instanceof WI.CanvasCollection);

        let contentPlaceholder = WI.createMessageTextView(WI.UIString("No Canvas Contexts"));
        let descriptionElement = contentPlaceholder.appendChild(document.createElement("div"));
        descriptionElement.className = "description";
        descriptionElement.textContent = WI.UIString("Waiting for canvas contexts created by script or CSS.");

        let importNavigationItem = new WI.ButtonNavigationItem("import-recording", WI.UIString("Import"), "Images/Import.svg", 15, 15);
        importNavigationItem.buttonStyle = WI.ButtonNavigationItem.Style.ImageAndText;
        importNavigationItem.addEventListener(WI.ButtonNavigationItem.Event.Clicked, () => { WI.canvasManager.importRecording(); });

        let importHelpElement = WI.createNavigationItemHelp(WI.UIString("Press %s to load a recording from file."), importNavigationItem);
        contentPlaceholder.appendChild(importHelpElement);

        super(representedObject, WI.CanvasContentView, contentPlaceholder);

        this.element.classList.add("canvas-overview");

        if (WI.CanvasManager.supportsRecordingAutoCapture()) {
            this._recordingAutoCaptureFrameCountInputElement = document.createElement("input");
            this._recordingAutoCaptureFrameCountInputElement.type = "number";
            this._recordingAutoCaptureFrameCountInputElement.min = 0;
            this._recordingAutoCaptureFrameCountInputElement.value = WI.settings.canvasRecordingAutoCaptureFrameCount.value;
            this._recordingAutoCaptureFrameCountInputElement.addEventListener("input", this._handleRecordingAutoCaptureInput.bind(this));

            let label = document.createDocumentFragment();
            String.format(WI.UIString("Record first %s frames"), [this._recordingAutoCaptureFrameCountInputElement], String.standardFormatters, label, (a, b) => {
                a.append(b);
                return a;
            });

            this._recordingAutoCaptureNavigationItem = new WI.CheckboxNavigationItem("canvas-recording-auto-capture", label, !!WI.settings.canvasRecordingAutoCaptureEnabled.value);
            this._recordingAutoCaptureNavigationItem.visibilityPriority = WI.NavigationItem.VisibilityPriority.Low;
            this._recordingAutoCaptureNavigationItem.addEventListener(WI.CheckboxNavigationItem.Event.CheckedDidChange, this._handleRecordingAutoCaptureCheckedDidChange, this);
        }

        this._importButtonNavigationItem = new WI.ButtonNavigationItem("import-recording", WI.UIString("Import"), "Images/Import.svg", 15, 15);
        this._importButtonNavigationItem.toolTip = WI.UIString("Import recording from file");
        this._importButtonNavigationItem.buttonStyle = WI.ButtonNavigationItem.Style.ImageAndText;
        this._importButtonNavigationItem.addEventListener(WI.ButtonNavigationItem.Event.Clicked, () => { WI.canvasManager.importRecording(); });

        this._refreshButtonNavigationItem = new WI.ButtonNavigationItem("refresh-all", WI.UIString("Refresh all"), "Images/ReloadFull.svg", 13, 13);
        this._refreshButtonNavigationItem.enabled = false;
        this._refreshButtonNavigationItem.addEventListener(WI.ButtonNavigationItem.Event.Clicked, this._refreshPreviews, this);

        this._showGridButtonNavigationItem = new WI.ActivateButtonNavigationItem("show-grid", WI.UIString("Show transparency grid"), WI.UIString("Hide Grid"), "Images/NavigationItemCheckers.svg", 13, 13);
        this._showGridButtonNavigationItem.activated = !!WI.settings.showImageGrid.value;
        this._showGridButtonNavigationItem.enabled = false;
        this._showGridButtonNavigationItem.addEventListener(WI.ButtonNavigationItem.Event.Clicked, this._showGridButtonClicked, this);
    }

    // Public

    get navigationItems()
    {
        let navigationItems = [this._importButtonNavigationItem, new WI.DividerNavigationItem, this._refreshButtonNavigationItem, this._showGridButtonNavigationItem];
        if (WI.CanvasManager.supportsRecordingAutoCapture())
            navigationItems.unshift(this._recordingAutoCaptureNavigationItem, new WI.DividerNavigationItem);
        return navigationItems;
    }

    hidden()
    {
        WI.domManager.hideDOMNodeHighlight();

        super.hidden();
    }

    // Protected

    initialLayout()
    {
        super.initialLayout();

        if (WI.CanvasManager.supportsRecordingAutoCapture()) {
            this._updateRecordingAutoCaptureInputElementSize();
            this._setRecordingAutoCaptureFrameCount();
        }
    }

    contentViewAdded(contentView)
    {
        contentView.element.addEventListener("mouseenter", this._contentViewMouseEnter);
        contentView.element.addEventListener("mouseleave", this._contentViewMouseLeave);

        this._updateNavigationItems();
    }

    contentViewRemoved(contentView)
    {
        contentView.element.removeEventListener("mouseenter", this._contentViewMouseEnter);
        contentView.element.removeEventListener("mouseleave", this._contentViewMouseLeave);

        this._updateNavigationItems();
    }

    attached()
    {
        super.attached();

        WI.settings.showImageGrid.addEventListener(WI.Setting.Event.Changed, this._updateShowImageGrid, this);
        WI.settings.canvasRecordingAutoCaptureEnabled.addEventListener(WI.Setting.Event.Changed, this._handleCanvasRecordingAutoCaptureEnabledChanged, this);
        WI.settings.canvasRecordingAutoCaptureFrameCount.addEventListener(WI.Setting.Event.Changed, this._handleCanvasRecordingAutoCaptureFrameCountChanged, this);
    }

    detached()
    {
        WI.settings.canvasRecordingAutoCaptureFrameCount.removeEventListener(null, null, this);
        WI.settings.canvasRecordingAutoCaptureEnabled.removeEventListener(null, null, this);
        WI.settings.showImageGrid.removeEventListener(null, null, this);

        super.detached();
    }

    // Private

    get _itemMargin()
    {
        return parseInt(window.getComputedStyle(this.element).getPropertyValue("--item-margin"));
    }

    _refreshPreviews()
    {
        for (let canvasContentView of this.subviews)
            canvasContentView.refresh();
    }

    _updateNavigationItems()
    {
        let hasItems = !!this.representedObject.size;
        this._refreshButtonNavigationItem.enabled = hasItems;
        this._showGridButtonNavigationItem.enabled = hasItems;
    }

    _showGridButtonClicked(event)
    {
        WI.settings.showImageGrid.value = !this._showGridButtonNavigationItem.activated;
    }

    _updateShowImageGrid()
    {
        this._showGridButtonNavigationItem.activated = !!WI.settings.showImageGrid.value;
    }

    _contentViewMouseEnter(event)
    {
        let contentView = WI.View.fromElement(event.target);
        if (!(contentView instanceof WI.CanvasContentView))
            return;

        let canvas = contentView.representedObject;
        if (canvas.cssCanvasName) {
            canvas.requestCSSCanvasClientNodes((cssCanvasClientNodes) => {
                WI.domManager.highlightDOMNodeList(cssCanvasClientNodes.map((node) => node.id));
            });
            return;
        }

        canvas.requestNode().then((node) => {
            if (!node || !node.ownerDocument)
                return;
            WI.domManager.highlightDOMNode(node.id);
        });
    }

    _contentViewMouseLeave(event)
    {
        WI.domManager.hideDOMNodeHighlight();
    }

    _setRecordingAutoCaptureFrameCount()
    {
        let frameCount = parseInt(this._recordingAutoCaptureFrameCountInputElement.value);
        console.assert(!isNaN(frameCount) && frameCount >= 0);

        let enabled = frameCount && !!this._recordingAutoCaptureNavigationItem.checked;

        WI.canvasManager.setRecordingAutoCaptureFrameCount(enabled, frameCount);
    }

    _updateRecordingAutoCaptureInputElementSize()
    {
        let frameCount = parseInt(this._recordingAutoCaptureFrameCountInputElement.value);
        if (isNaN(frameCount) || frameCount < 0) {
            frameCount = 0;
            this._recordingAutoCaptureFrameCountInputElement.value = frameCount;
        }

        WI.ImageUtilities.scratchCanvasContext2D((context) => {
            if (!this._recordingAutoCaptureFrameCountInputElement.__cachedFont) {
                let computedStyle = window.getComputedStyle(this._recordingAutoCaptureFrameCountInputElement);
                this._recordingAutoCaptureFrameCountInputElement.__cachedFont = computedStyle.font;
            }

            context.font = this._recordingAutoCaptureFrameCountInputElement.__cachedFont;
            let textMetrics = context.measureText(this._recordingAutoCaptureFrameCountInputElement.value);
            this._recordingAutoCaptureFrameCountInputElement.style.setProperty("width", (textMetrics.width + 8) + "px");
        });

        this._recordingAutoCaptureNavigationItem.checked = !!frameCount;
    }

    _handleRecordingAutoCaptureInput(event)
    {
        this._updateRecordingAutoCaptureInputElementSize();
        this._setRecordingAutoCaptureFrameCount();
    }

    _handleRecordingAutoCaptureCheckedDidChange(event)
    {
        this._setRecordingAutoCaptureFrameCount();
    }

    _handleCanvasRecordingAutoCaptureEnabledChanged(event)
    {
        this._recordingAutoCaptureNavigationItem.checked = WI.settings.canvasRecordingAutoCaptureEnabled.value;
    }

    _handleCanvasRecordingAutoCaptureFrameCountChanged(event)
    {
        this._recordingAutoCaptureFrameCountInputElement.value = WI.settings.canvasRecordingAutoCaptureFrameCount.value;
    }
};
