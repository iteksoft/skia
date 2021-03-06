/*
 * Copyright 2021 Google LLC
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include "experimental/graphite/src/CommandBuffer.h"

#include "experimental/graphite/include/private/GraphiteTypesPriv.h"
#include "experimental/graphite/src/RenderPipeline.h"
#include "src/core/SkTraceEvent.h"

#include "experimental/graphite/src/Buffer.h"
#include "experimental/graphite/src/Texture.h"

namespace skgpu {

CommandBuffer::CommandBuffer() {}

void CommandBuffer::releaseResources() {
    TRACE_EVENT0("skia.gpu", TRACE_FUNC);

    fTrackedResources.reset();
}

void CommandBuffer::beginRenderPass(const RenderPassDesc& renderPassDesc) {
    this->onBeginRenderPass(renderPassDesc);

    auto& colorInfo = renderPassDesc.fColorAttachment;
    if (colorInfo.fTexture) {
        this->trackResource(std::move(colorInfo.fTexture));
    }
    if (colorInfo.fStoreOp == StoreOp::kStore) {
        fHasWork = true;
    }
}

void CommandBuffer::setRenderPipeline(sk_sp<RenderPipeline> renderPipeline) {
    this->onSetRenderPipeline(renderPipeline);
    this->trackResource(std::move(renderPipeline));
    fHasWork = true;
}

static bool check_max_blit_width(int widthInPixels) {
    if (widthInPixels > 32767) {
        SkASSERT(false); // surfaces should not be this wide anyway
        return false;
    }
    return true;
}

void CommandBuffer::copyTextureToBuffer(sk_sp<skgpu::Texture> texture,
                                        SkIRect srcRect,
                                        sk_sp<skgpu::Buffer> buffer,
                                        size_t bufferOffset,
                                        size_t bufferRowBytes) {
    if (!check_max_blit_width(srcRect.width())) {
        return;
    }

    this->onCopyTextureToBuffer(texture, srcRect, buffer, bufferOffset, bufferRowBytes);

    this->trackResource(std::move(texture));
    this->trackResource(std::move(buffer));

    fHasWork = true;
}

} // namespace skgpu
