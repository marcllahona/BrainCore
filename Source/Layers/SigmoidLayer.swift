// Copyright © 2016 Venture Media Labs. All rights reserved.
//
// This file is part of BrainCore. The full BrainCore copyright notice,
// including terms governing use, modification, and redistribution, is
// contained in the file LICENSE at the root of the source code distribution
// tree.

import Foundation
import Metal

public class SigmoidLayer: ForwardLayer, BackwardLayer {
    /// The size of each batch element
    public let size: Int

    public var outputSize: Int {
        return size
    }

    public var inputSize: Int {
        return size
    }

    public init(size: Int) {
        self.size = size
    }

    struct SigmoidDimensions {
        let batchSize: UInt32
        let size: UInt32
    }

    static let forwardFunctionName = "sigmoid_forward"
    static let backwardFunctionName = "sigmoid_backward"

    public var forwardFunction: MTLComputePipelineState!
    public var backwardFunction: MTLComputePipelineState!

    public func setupInLibrary(library: MTLLibrary) throws {
        let forwardLibraryFunction = library.newFunctionWithName(SigmoidLayer.forwardFunctionName)!
        forwardFunction = try library.device.newComputePipelineStateWithFunction(forwardLibraryFunction)

        let backwardLibraryFunction = library.newFunctionWithName(SigmoidLayer.backwardFunctionName)!
        backwardFunction = try library.device.newComputePipelineStateWithFunction(backwardLibraryFunction)
    }

    public func encodeForwardInBuffer(buffer: MTLCommandBuffer, batchSize: Int, input: MTLBuffer, offset inputOffset: Int, output: MTLBuffer, offset outputOffset: Int) {
        var dimensions = SigmoidDimensions(batchSize: UInt32(batchSize), size: UInt32(size))
        let dimensionsBuffer = buffer.device.newBufferWithBytes(&dimensions, length: sizeof(SigmoidDimensions), options: .CPUCacheModeWriteCombined)
        dimensionsBuffer.label = "SigmoidDimensions"

        let encoder = buffer.computeCommandEncoder()
        encoder.label = "SigmoidForward"
        encoder.setComputePipelineState(forwardFunction)
        encoder.setBuffer(input, offset: inputOffset * sizeof(Float), atIndex: 0)
        encoder.setBuffer(output, offset: outputOffset * sizeof(Float), atIndex: 1)
        encoder.setBuffer(dimensionsBuffer, offset: 0, atIndex: 2)

        let count = size * batchSize
        let threadsPerGroup = MTLSize(width: forwardFunction.threadExecutionWidth, height: 1, depth: 1)
        let numThreadgroups = MTLSize(width: (count - 1) / forwardFunction.threadExecutionWidth + 1, height: 1, depth:1)
        encoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)

        encoder.endEncoding()
    }

    public func encodeBackwardInBuffer(buffer: MTLCommandBuffer, batchSize: Int, outputDiff: MTLBuffer, input: MTLBuffer, inputDiff: MTLBuffer) {
        var dimensions = SigmoidDimensions(batchSize: UInt32(batchSize), size: UInt32(size))
        let dimensionsBuffer = buffer.device.newBufferWithBytes(&dimensions, length: sizeof(SigmoidDimensions), options: .CPUCacheModeWriteCombined)
        dimensionsBuffer.label = "SigmoidDimensions"

        let encoder = buffer.computeCommandEncoder()
        encoder.label = "SigmoidBackward"
        encoder.setComputePipelineState(backwardFunction)
        encoder.setBuffer(outputDiff, offset: 0, atIndex: 0)
        encoder.setBuffer(input, offset: 0, atIndex: 1)
        encoder.setBuffer(inputDiff, offset: 0, atIndex: 2)
        encoder.setBuffer(dimensionsBuffer, offset: 0, atIndex: 3)

        let count = size * batchSize
        let threadsPerGroup = MTLSize(width: backwardFunction.threadExecutionWidth, height: 1, depth: 1)
        let numThreadgroups = MTLSize(width: (count - 1) / backwardFunction.threadExecutionWidth + 1, height: 1, depth:1)
        encoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
        
        encoder.endEncoding()
    }
}