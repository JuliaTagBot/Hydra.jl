import SIMD
using SIMD: ScalarTypes

datatype(x::SIMD.Vec{N,T}) where {N,T} = T

# Scalar vector type
# Essentially equivalent to what SIMD.jl provides; we only reproduce it
# so that it fits into our `AbstractVec` framework.

struct SVec{T,N} <: AbstractVec{T,N}
  data::NTuple{N,VecElement{T}}
  SVec{T,N}(data::NTuple{N,VecElement{T}}) where {T,N} = new(data)
end

SVec(xs::NTuple{N,VecElement{T}}) where {T,N} = SVec{T,N}(xs)
SVec(xs::NTuple{N,T}) where {T,N} = SVec{T,N}(map(VecElement, xs))

# SIMD vectors are buggy – https://github.com/JuliaLang/julia/issues/30056
# Flip this to test programs without using them.
vect(xs::T...) where {T} = SVec(xs)
# vect(xs::T...) where {T} = Vec(xs)

data(xs::SVec) = getfield.(xs.data, :value)

Base.summary(::SVec) = "SVec"

Base.convert(::Type{SIMD.Vec}, x::SVec{T,N}) where {T,N} =
  SIMD.Vec{N,T}(x.data)

simd_vec(x::SVec) = convert(SIMD.Vec, x)
simd_vec(x) = x

SVecOrVal{T} = Union{SVec{T},T}

vecconvert(T, x::SIMD.Vec) = convert(SIMD.Vec{length(x),T}, x)
vecconvert(T, x) = convert(T, x)

vecpromote(xs...) = map(x -> vecconvert(promote_type(map(datatype, xs)...), x), xs)

# Arithmetic operations (forward to SIMD.jl)

for op in :[+, -, *, /, div, rem, &, |, !,
            ==, !=, >, >=, <, <=].args
    @eval begin
        spmd(mask::Mask, ::typeof($op), xs::SVecOrVal{T}...) where T <: ScalarTypes =
          $op(map(simd_vec, xs)...)
        # TODO: remove this when we can compile the usual promotion mechanisms
        spmd(mask::Mask, ::typeof($op), xs::SVecOrVal{<:ScalarTypes}...) =
          $op(promote_vec(map(simd_vec, xs)...)...)
    end
end
