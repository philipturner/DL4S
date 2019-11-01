//
//  Layer.swift
//  DL4S
//
//  Created by Palle Klewitz on 12.10.19.
//  Copyright (c) 2019 - Palle Klewitz
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation

/// A layer of a neural network that performs an arbitrary transformation on its inputs to generate its outputs.
/// The layer may have parameters, which influence, how the outputs are generated.
@dynamicCallable
public protocol LayerType {
    /// Inputs of the layer
    associatedtype Inputs
    
    /// Outputs of the layer
    associatedtype Outputs
    
    /// Element type of a parameter tensor
    associatedtype Parameter: NumericType
    
    /// Device type of a parameter tensor
    associatedtype Device: DeviceType
    
    /// Keypaths to parameters that influence the output of the layer
    var parameterPaths: [WritableKeyPath<Self, Tensor<Parameter, Device>>] { get }
    
    /// Parameters, that influence the output of the layer.
    var parameters: [Tensor<Parameter, Device>] { get }
    
    
    /// Performs a transformation determined by the type of the layer.
    ///
    /// The transformation may use parameters that the layer has.
    /// - Parameter inputs: Inputs of the layer
    /// - Returns: Outputs generated by transforming the inputs using the parameters of the layer.
    func callAsFunction(_ inputs: Inputs) -> Outputs
}

public extension LayerType {
    /// Dynamic callable extension, as static callable is not yet available
    /// - Parameter arguments: Inputs of the layer.
    func dynamicallyCall(withArguments arguments: [Inputs]) -> Outputs {
        return callAsFunction(arguments[0])
    }
}


/// Type erased layer
public struct AnyLayer<Inputs, Outputs, Parameter: NumericType, Device: DeviceType>: LayerType {
    public var parameterPaths: [WritableKeyPath<Self, Tensor<Parameter, Device>>] {
        parameters.indices.map {
            \Self.parameters[$0]
        }
    }
    
    public var parameters: [Tensor<Parameter, Device>] {
        get { getParameters() }
        set { setParameters(newValue) }
    }
    
    private var getParameters: () -> [Tensor<Parameter, Device>]
    private var setParameters: ([Tensor<Parameter, Device>]) -> ()
    private var forward: (Inputs) -> Outputs
    
    /// Creates a layer by type-erasing the given layer
    /// - Parameter wrappedLayer: Layer to wrap.
    public init<L: LayerType>(_ wrappedLayer: L) where L.Inputs == Inputs, L.Outputs == Outputs, L.Parameter == Parameter, L.Device == Device {
        var wrappedLayer = wrappedLayer
        let paths = wrappedLayer.parameterPaths
        
        getParameters = {
            wrappedLayer.parameters
        }
        setParameters = {
            zip(paths, $0).forEach {
                wrappedLayer[keyPath: $0] = $1
            }
        }
        forward = {
            wrappedLayer.callAsFunction($0)
        }
    }
    
    public func callAsFunction(_ inputs: Inputs) -> Outputs {
        forward(inputs)
    }
}
