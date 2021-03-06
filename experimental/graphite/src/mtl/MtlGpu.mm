/*
 * Copyright 2021 Google LLC
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include "experimental/graphite/src/mtl/MtlGpu.h"

#include "experimental/graphite/src/Caps.h"
#include "experimental/graphite/src/mtl/MtlCommandBuffer.h"
#include "experimental/graphite/src/mtl/MtlResourceProvider.h"

namespace skgpu::mtl {

sk_sp<skgpu::Gpu> Gpu::Make(const BackendContext& context) {
    sk_cfp<id<MTLDevice>> device = sk_ret_cfp((id<MTLDevice>)(context.fDevice.get()));
    sk_cfp<id<MTLCommandQueue>> queue = sk_ret_cfp((id<MTLCommandQueue>)(context.fQueue.get()));

    sk_sp<const Caps> caps(new Caps(device.get()));

    return sk_sp<skgpu::Gpu>(new Gpu(std::move(device), std::move(queue), std::move(caps)));
}

Gpu::Gpu(sk_cfp<id<MTLDevice>> device, sk_cfp<id<MTLCommandQueue>> queue, sk_sp<const Caps> caps)
    : skgpu::Gpu(std::move(caps))
    , fDevice(std::move(device))
    , fQueue(std::move(queue)) {
    fResourceProvider.reset(new ResourceProvider(this));
}

Gpu::~Gpu() {
}

class WorkSubmission final : public skgpu::GpuWorkSubmission {
public:
    WorkSubmission(sk_sp<CommandBuffer> cmdBuffer)
        : fCommandBuffer(std::move(cmdBuffer)) {}
    ~WorkSubmission() override {}

    bool isFinished() override {
        return fCommandBuffer->isFinished();
    }
    void waitUntilFinished(const skgpu::Gpu*) override {
        return fCommandBuffer->waitUntilFinished();
    }

private:
    sk_sp<CommandBuffer> fCommandBuffer;
};

bool Gpu::onSubmit(sk_sp<skgpu::CommandBuffer> commandBuffer) {
    SkASSERT(commandBuffer);
    sk_sp<CommandBuffer>& mtlCmdBuffer = (sk_sp<CommandBuffer>&)(commandBuffer);
    if (!mtlCmdBuffer->commit()) {
        return false;
    }

    std::unique_ptr<WorkSubmission> submission(new WorkSubmission(mtlCmdBuffer));
    new (fOutstandingSubmissions.push_back()) OutstandingSubmission(std::move(submission));

    return true;
}

#if GRAPHITE_TEST_UTILS
void Gpu::testingOnly_startCapture() {
    if (@available(macOS 10.13, iOS 11.0, *)) {
        // TODO: add newer Metal interface as well
        MTLCaptureManager* captureManager = [MTLCaptureManager sharedCaptureManager];
        if (captureManager.isCapturing) {
            return;
        }
        if (@available(macOS 10.15, iOS 13.0, *)) {
            MTLCaptureDescriptor* captureDescriptor = [[MTLCaptureDescriptor alloc] init];
            captureDescriptor.captureObject = fQueue.get();

            NSError *error;
            if (![captureManager startCaptureWithDescriptor: captureDescriptor error:&error])
            {
                NSLog(@"Failed to start capture, error %@", error);
            }
        } else {
            [captureManager startCaptureWithCommandQueue: fQueue.get()];
        }
     }
}

void Gpu::testingOnly_endCapture() {
    if (@available(macOS 10.13, iOS 11.0, *)) {
        MTLCaptureManager* captureManager = [MTLCaptureManager sharedCaptureManager];
        if (captureManager.isCapturing) {
            [captureManager stopCapture];
        }
    }
}
#endif

} // namespace skgpu::mtl
