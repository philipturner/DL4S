//
//  WGANGPTests.swift
//  DL4S
//
//  Created by Palle Klewitz on 15.10.19.
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
import XCTest
@testable import DL4S


class WGANGPTests: XCTestCase {
    func testWGANGP() {
        var generator = XUnion {
            XDense<Float, CPU>(inputSize: 50, outputSize: 200)
            XBatchNorm<Float, CPU>(inputSize: [200])
            XLeakyRelu<Float, CPU>(leakage: 0.2)
            
            XDense<Float, CPU>(inputSize: 200, outputSize: 800)
            XBatchNorm<Float, CPU>(inputSize: [800])
            XLeakyRelu<Float, CPU>(leakage: 0.2)
            
            XDense<Float, CPU>(inputSize: 800, outputSize: 28 * 28)
            XSigmoid<Float, CPU>()
        }
        generator.tag = "Generator"
        
        var critic = XUnion {
            XDense<Float, CPU>(inputSize: 28 * 28, outputSize: 400)
            XRelu<Float, CPU>()
            
            XDense<Float, CPU>(inputSize: 400, outputSize: 100)
            XRelu<Float, CPU>()
            
            XDense<Float, CPU>(inputSize: 100, outputSize: 1)
        }
        critic.tag = "Discriminator"
        
        print("Loading images...")
        let ((images, labels_cat), _) = MNistTest.images(from: "/Users/Palle/Downloads/")
        
        let labels = labels_cat.toOneHot(dim: 10) as Tensor<Float, CPU>
        
        print("Creating networks...")
        
        var optimGen = XAdam(model: generator, learningRate: 0.0001, beta1: 0.0, beta2: 0.9)
        var optimCrit = XAdam(model: critic, learningRate: 0.0001, beta1: 0.0, beta2: 0.9)
        
        let batchSize = 32
        let epochs = 20_000
        let n_critic = 5
        let lambda = XTensor<Float, CPU>(10)
        
        print("Training...")
        
        
        for epoch in 1 ... epochs {
            var lastCriticDiscriminationLoss: XTensor<Float, CPU> = 0
            var lastGradientPenaltyLoss: XTensor<Float, CPU> = 0
            
            for _ in 0 ..< n_critic {
                let (realT, _) = Random.minibatch(from: images, labels: labels, count: batchSize)
                let real = XTensor(realT.view(as: [batchSize, 28 * 28]))

                let genInputsT = Tensor<Float, CPU>(repeating: 0, shape: batchSize, 50)
                Random.fill(genInputsT, a: 0, b: 1)
                let genInputs = XTensor(genInputsT)
                
                let fakeGenerated = optimGen.model(genInputs)
                
                let eps = XTensor<Float, CPU>(Float.random(in: 0 ... 1))
                let mixed = real * eps + fakeGenerated * (1 - eps)
                
                let fakeDiscriminated = optimCrit.model(mixed)
                let realDiscriminated = optimCrit.model(real)
                
                let criticDiscriminationLoss = OperationGroup.capture(named: "CriticDiscriminationLoss") {
                    fakeDiscriminated.reduceMean() - realDiscriminated.reduceMean()
                }
                
                let gradientPenaltyLoss = OperationGroup.capture(named: "GradientPenaltyLoss") { () -> XTensor<Float, CPU> in
                    let fakeGeneratedGrad = fakeDiscriminated.gradients(of: [mixed], retainBackwardsGraph: true)[0]
                    let partialPenaltyTerm = (fakeGeneratedGrad * fakeGeneratedGrad).reduceSum(along: [1]).sqrt() - 1
                    let gradientPenaltyLoss = lambda * (partialPenaltyTerm * partialPenaltyTerm).reduceMean()
                    return gradientPenaltyLoss
                }
                
                let criticLoss = criticDiscriminationLoss + gradientPenaltyLoss
                let criticGradients = criticLoss.gradients(of: optimCrit.model.parameters)
                
                optimCrit.update(along: criticGradients)
                
                lastCriticDiscriminationLoss = criticDiscriminationLoss.detached()
                lastGradientPenaltyLoss = gradientPenaltyLoss.detached()
            }

            let genInputsT = Tensor<Float, CPU>(repeating: 0, shape: batchSize, 50)
            Random.fill(genInputsT, a: 0, b: 1)
            let genInputs = XTensor(genInputsT)
            
            let fakeGenerated = optimGen.model(genInputs)
            let fakeDiscriminated = optimCrit.model(fakeGenerated)
            let generatorLoss = -fakeDiscriminated.reduceMean()
            
            let generatorGradients = generatorLoss.gradients(of: optimGen.model.parameters)

            optimGen.update(along: generatorGradients)

            if epoch.isMultiple(of: 100) {
                print(" [\(epoch)/\(epochs)] loss c: \(lastCriticDiscriminationLoss), gp: \(lastGradientPenaltyLoss), g: \(generatorLoss)")
            }
            
            if epoch.isMultiple(of: 1000) {
                let genInputsT = Tensor<Float, CPU>(repeating: 0, shape: batchSize, 50)
                Random.fill(genInputsT, a: 0, b: 1)
                let genInputs = XTensor(genInputsT)
                
                let fakeGenerated = optimGen.model(genInputs).view(as: [-1, 28, 28])
                
                for i in 0 ..< 32 {
                    let slice = fakeGenerated[i].permuted(to: [1, 0]).unsqueezed(at: 0)
                    guard let image = NSImage(slice), let imgData = image.tiffRepresentation else {
                        continue
                    }
                    guard let rep = NSBitmapImageRep(data: imgData) else {
                        continue
                    }
                    let png = rep.representation(using: .png, properties: [:])
                    try? png?.write(to: URL(fileURLWithPath: "/Users/Palle/Desktop/wgan_gp/gen_\(epoch)_\(i).png"))
                }
            }
        }
        
    }
}
