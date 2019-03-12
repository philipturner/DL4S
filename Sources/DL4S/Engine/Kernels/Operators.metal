//
//  kernels.metal
//  DL4S
//
//  Created by Palle Klewitz on 10.03.19.
//

#include <metal_stdlib>
using namespace metal;

class Shape {
public:
    const int dim;
    const device int* shape;
    
    Shape(const int d, const device int* s): dim(d), shape(s) {}
    
    const int getCount() const;
    const int operator[](int index) const;
    const int broadcastIndex(int globalIndex) const;
};


const int Shape::getCount() const {
    int count = 1;
    for (int axis = 0; axis < this->dim; axis++) {
        count *= shape[axis];
    }
    return count;
}

const int Shape::operator[](int index) const {
    return this->shape[index];
}

const int Shape::broadcastIndex(int globalIndex) const {
    return globalIndex % this->getCount();
}

template <typename element_t>
class Tensor {
private:
    const device element_t* elements;
    
public:
    const Shape shape;
    Tensor(Shape s, const device element_t* el) : shape(s), elements(el) {}
    element_t get(int idx) const;
};

template <typename element_t>
class MutableTensor {
private:
    device element_t* elements;
    
public:
    const Shape shape;
    MutableTensor(Shape s, device element_t* el) : shape(s), elements(el) {}
    
    element_t get(int idx) const;
    void set(int idx, element_t value);
};

template <typename element_t>
element_t Tensor<element_t>::get(int idx) const {
    return this->elements[idx];
}

template <typename element_t>
element_t MutableTensor<element_t>::get(int idx) const {
    return this->elements[idx];
}


template <typename element_t>
void MutableTensor<element_t>::set(int idx, element_t value) {
    this->elements[idx] = value;
}


kernel void vAdd_Broadcast_Float32(
    const device float* lhs_vals [[buffer(0)]],
    constant int &lhs_dim [[buffer(1)]],
    const device int* lhs_shape [[buffer(2)]],
    const device float* rhs_vals [[buffer(3)]],
    constant int &rhs_dim [[buffer(4)]],
    const device int* rhs_shape [[buffer(5)]],
    device float* result_vals [[buffer(6)]],
    uint pos [[thread_position_in_grid]]
) {
    auto lhs = Tensor<float>(Shape(lhs_dim, lhs_shape), lhs_vals);
    auto rhs = Tensor<float>(Shape(rhs_dim, rhs_shape), rhs_vals);
    
    if (lhs.shape.dim >= rhs.shape.dim) {
        auto result = MutableTensor<float>(lhs.shape, result_vals);
        result.set(pos, lhs.get(pos) + rhs.get(rhs.shape.broadcastIndex(pos)));
    } else {
        auto result = MutableTensor<float>(rhs.shape, result_vals);
        result.set(pos, lhs.get(rhs.shape.broadcastIndex(pos)) + rhs.get(pos));
    }
}


kernel void vSub_Broadcast_Float32(
    const device float* lhs_vals [[buffer(0)]],
    constant int &lhs_dim [[buffer(1)]],
    const device int* lhs_shape [[buffer(2)]],
    const device float* rhs_vals [[buffer(3)]],
    constant int &rhs_dim [[buffer(4)]],
    const device int* rhs_shape [[buffer(5)]],
    device float* result_vals [[buffer(6)]],
    uint pos [[thread_position_in_grid]]
) {
    auto lhs = Tensor<float>(Shape(lhs_dim, lhs_shape), lhs_vals);
    auto rhs = Tensor<float>(Shape(rhs_dim, rhs_shape), rhs_vals);
    
    if (lhs.shape.dim >= rhs.shape.dim) {
        auto result = MutableTensor<float>(lhs.shape, result_vals);
        result.set(pos, lhs.get(pos) - rhs.get(rhs.shape.broadcastIndex(pos)));
    } else {
        auto result = MutableTensor<float>(rhs.shape, result_vals);
        result.set(pos, lhs.get(rhs.shape.broadcastIndex(pos)) - rhs.get(pos));
    }
}

kernel void vMul_Broadcast_Float32(
    const device float* lhs_vals [[buffer(0)]],
    constant int &lhs_dim [[buffer(1)]],
    const device int* lhs_shape [[buffer(2)]],
    const device float* rhs_vals [[buffer(3)]],
    constant int &rhs_dim [[buffer(4)]],
    const device int* rhs_shape [[buffer(5)]],
    device float* result_vals [[buffer(6)]],
    uint pos [[thread_position_in_grid]]
) {
    auto lhs = Tensor<float>(Shape(lhs_dim, lhs_shape), lhs_vals);
    auto rhs = Tensor<float>(Shape(rhs_dim, rhs_shape), rhs_vals);

    if (lhs.shape.dim >= rhs.shape.dim) {
        auto result = MutableTensor<float>(lhs.shape, result_vals);
        result.set(pos, lhs.get(pos) * rhs.get(rhs.shape.broadcastIndex(pos)));
    } else {
        auto result = MutableTensor<float>(rhs.shape, result_vals);
        result.set(pos, lhs.get(rhs.shape.broadcastIndex(pos)) * rhs.get(pos));
    }
}

kernel void vDiv_Broadcast_Float32(
    const device float* lhs_vals [[buffer(0)]],
    constant int &lhs_dim [[buffer(1)]],
    const device int* lhs_shape [[buffer(2)]],
    const device float* rhs_vals [[buffer(3)]],
    constant int &rhs_dim [[buffer(4)]],
    const device int* rhs_shape [[buffer(5)]],
    device float* result_vals [[buffer(6)]],
    uint pos [[thread_position_in_grid]]
) {
    auto lhs = Tensor<float>(Shape(lhs_dim, lhs_shape), lhs_vals);
    auto rhs = Tensor<float>(Shape(rhs_dim, rhs_shape), rhs_vals);

    if (lhs.shape.dim >= rhs.shape.dim) {
        auto result = MutableTensor<float>(lhs.shape, result_vals);
        result.set(pos, lhs.get(pos) / rhs.get(rhs.shape.broadcastIndex(pos)));
    } else {
        auto result = MutableTensor<float>(rhs.shape, result_vals);
        result.set(pos, lhs.get(rhs.shape.broadcastIndex(pos)) / rhs.get(pos));
    }
}


kernel void vExp_Float32(
    const device float* src_vals [[buffer(0)]],
    device float* result_vals [[buffer(1)]],
    uint pos [[thread_position_in_grid]]
) {
    result_vals[pos] = exp(src_vals[pos]);
}

kernel void vLog_Float32(
    const device float* src_vals [[buffer(0)]],
    device float* result_vals [[buffer(1)]],
    uint pos [[thread_position_in_grid]]
) {
    result_vals[pos] = log(src_vals[pos]);
}

kernel void vSqrt_Float32(
    const device float* src_vals [[buffer(0)]],
    device float* result_vals [[buffer(1)]],
    uint pos [[thread_position_in_grid]]
) {
    result_vals[pos] = sqrt(src_vals[pos]);
}

kernel void vSin_Float32(
    const device float* src_vals [[buffer(0)]],
    device float* result_vals [[buffer(1)]],
    uint pos [[thread_position_in_grid]]
) {
    result_vals[pos] = sin(src_vals[pos]);
}

kernel void vCos_Float32(
    const device float* src_vals [[buffer(0)]],
    device float* result_vals [[buffer(1)]],
    uint pos [[thread_position_in_grid]]
) {
    result_vals[pos] = cos(src_vals[pos]);
}

kernel void vTan_Float32(
    const device float* src_vals [[buffer(0)]],
    device float* result_vals [[buffer(1)]],
    uint pos [[thread_position_in_grid]]
) {
    result_vals[pos] = tan(src_vals[pos]);
}

kernel void vSinh_Float32(
    const device float* src_vals [[buffer(0)]],
    device float* result_vals [[buffer(1)]],
    uint pos [[thread_position_in_grid]]
) {
    result_vals[pos] = sinh(src_vals[pos]);
}

kernel void vCosh_Float32(
    const device float* src_vals [[buffer(0)]],
    device float* result_vals [[buffer(1)]],
    uint pos [[thread_position_in_grid]]
) {
    result_vals[pos] = cosh(src_vals[pos]);
}

kernel void vTanh_Float32(
    const device float* src_vals [[buffer(0)]],
    device float* result_vals [[buffer(1)]],
    uint pos [[thread_position_in_grid]]
) {
    result_vals[pos] = tanh(src_vals[pos]);
}

kernel void vSquare_Float32(
    const device float* src_vals [[buffer(0)]],
    device float* result_vals [[buffer(1)]],
    uint pos [[thread_position_in_grid]]
) {
    result_vals[pos] = src_vals[pos] * src_vals[pos];
}

kernel void vRelu_Float32(
    const device float* src_vals [[buffer(0)]],
    device float* result_vals [[buffer(1)]],
    uint pos [[thread_position_in_grid]]
) {
    result_vals[pos] = max(src_vals[pos], 0.0f);
}

kernel void vPositive_Float32(
    const device float* src_vals [[buffer(0)]],
    device float* result_vals [[buffer(1)]],
    uint pos [[thread_position_in_grid]]
) {
    result_vals[pos] = src_vals[pos] > 0.0f ? 1.0f : 0.0f;
}

kernel void mmul_Broadcast_Float32(
    const device float* lhs_vals [[buffer(0)]],
    constant int &lhs_dim [[buffer(1)]],
    const device int* lhs_shape [[buffer(2)]],
    const device float* rhs_vals [[buffer(3)]],
    constant int &rhs_dim [[buffer(4)]],
    const device int* rhs_shape [[buffer(5)]],
    device float* result_vals [[buffer(6)]],
    constant int &result_dim [[buffer(7)]],
    const device int* result_shape [[buffer(8)]],
    uint2 pos [[thread_position_in_grid]]
) {
    int column = pos.x;
    int row = pos.y;
    int count = lhs_shape[1];
    int rhs_cols = rhs_shape[1];
    
    float result = 0.0f;
    
    for (int i = 0; i < count; i++) {
        int lhs_idx = row * count + i;
        int rhs_idx = rhs_cols * i + column;
        
        result += lhs_vals[lhs_idx] * rhs_vals[rhs_idx];
    }
    
    int dstIdx = result_shape[1] * row + column;
    result_vals[dstIdx] = result;
}
