struct DiffEqNLSolveTag end

immutable DiffCache{T<:AbstractArray, S<:AbstractArray}
    du::T
    dual_du::S
end

Base.@pure function DiffCache{chunk_size}(T, size, ::Type{Val{chunk_size}})
    DiffCache(zeros(T, size...), zeros(Dual{typeof(ForwardDiff.Tag(DiffEqNLSolveTag(),T)),T,chunk_size}, size...))
end

Base.@pure DiffCache(u::AbstractArray) = DiffCache(eltype(u),size(u),Val{ForwardDiff.pickchunksize(length(u))})
Base.@pure DiffCache(u::AbstractArray,nlsolve) = DiffCache(eltype(u),size(u),Val{get_chunksize(nlsolve)})
Base.@pure DiffCache{CS}(u::AbstractArray,T::Type{Val{CS}}) = DiffCache(eltype(u),size(u),T)

get_du{T<:Dual}(dc::DiffCache, ::Type{T}) = dc.dual_du
get_du(dc::DiffCache, T) = dc.du

# Default nlsolve behavior, should move to DiffEqDiffTools.jl

Base.@pure determine_chunksize(u,alg::DEAlgorithm) = determine_chunksize(u,get_chunksize(alg))
Base.@pure function determine_chunksize(u,CS)
  if CS != 0
    return CS
  else
    return ForwardDiff.pickchunksize(length(u))
  end
end

function autodiff_setup{CS}(f!, initial_x, chunk_size::Type{Val{CS}})
    fvec! = NLsolve.reshape_f(f!, initial_x)
    permf! = (fx, x) -> fvec!(x, fx)

    fx2 = vec(copy(initial_x))
    jac_cfg = ForwardDiff.JacobianConfig(DiffEqNLSolveTag(),
                                         vec(initial_x), vec(initial_x),
                                         ForwardDiff.Chunk{CS}())
    g! = (x, gx) -> ForwardDiff.jacobian!(gx, permf!, fx2, x, jac_cfg,Val{false}())
    fg! = (x, fx, gx) -> begin
        jac_res = DiffBase.DiffResult(fx, gx)
        ForwardDiff.jacobian!(jac_res, permf!, fx2, x, jac_cfg,Val{false}())
        DiffBase.value(jac_res)
    end

    return DifferentiableMultivariateFunction(fvec!, g!, fg!)
end

function non_autodiff_setup(f!, initial_x)
  DifferentiableMultivariateFunction(f!, initial_x)
end

immutable NLSOLVEJL_SETUP{CS,AD} end
Base.@pure NLSOLVEJL_SETUP(;chunk_size=0,autodiff=true) = NLSOLVEJL_SETUP{chunk_size,autodiff}()
(p::NLSOLVEJL_SETUP)(f,u0; kwargs...) = (res=NLsolve.nlsolve(f,u0; kwargs...); res.zero)
function (p::NLSOLVEJL_SETUP{CS,AD}){CS,AD}(::Type{Val{:init}},f,u0_prototype)
  if AD
    return autodiff_setup(f,u0_prototype,Val{determine_chunksize(u0_prototype,CS)})
  else
    return non_autodiff_setup(f,u0_prototype)
  end
end

get_chunksize(x) = 0
get_chunksize{CS,AD}(x::NLSOLVEJL_SETUP{CS,AD}) = CS

export NLSOLVEJL_SETUP

"""
    calculate_residuals!(out, ũ, u₀, u₁, α, ρ)

Save element-wise residuals
```math
\frac{ũ}{α+\max{|u₀|,|u₁|}*ρ}
```
in `out`.
"""
@inline @muladd function calculate_residuals!(out, ũ, u₀, u₁, α, ρ, internalnorm)
    @. out = ũ / (α + max(internalnorm(u₀), internalnorm(u₁)) * ρ)
end

@inline @muladd function calculate_residuals!(out::Array{T}, ũ::Array{T}, u₀::Array{T},
                                              u₁::Array{T}, α::T, ρ::Real,
                                              internalnorm) where {T<:Number}
    @tight_loop_macros for i in eachindex(out)
        @inbounds out[i] = ũ[i] / (α + max(internalnorm(u₀[i]), internalnorm(u₁[i])) * ρ)
    end
end

"""
    calculate_residuals!(out, u₀, u₁, α, ρ)

Save element-wise residuals
```math
\frac{u₁-u₀}{α+\max{|u₀|,|u₁|}*ρ}
```
in `out`.
"""
@inline @muladd function calculate_residuals!(out, u₀, u₁, α, ρ, internalnorm)
    @. out = (u₁ - u₀) / (α + max(internalnorm(u₀), internalnorm(u₁)) * ρ)
end

@inline @muladd function calculate_residuals!(out::Array{T}, u₀::Array{T},
                                              u₁::Array{T}, α::T, ρ::Real,
                                              internalnorm) where {T<:Number}
    @tight_loop_macros for i in eachindex(out)
        @inbounds out[i] = (u₁[i] - u₀[i]) / (α + max(internalnorm(u₀[i]), internalnorm(u₁[i])) * ρ)
    end
end

"""
    calculate_residuals(ũ, u₀, u₁, α, ρ)

Calculate element-wise residuals
```math
\frac{ũ}{α+\max{|u₀|,|u₁|}*ρ}.
```
"""
@inline @muladd function calculate_residuals(ũ, u₀, u₁, α, ρ, internalnorm)
    @. ũ / (α + max(internalnorm(u₀), internalnorm(u₁)) * ρ)
end

@inline @muladd function calculate_residuals(ũ::Array{T}, u₀::Array{T}, u₁::Array{T}, α::T,
                                             ρ::Real, internalnorm) where {T<:Number}
    out = similar(ũ)
    calculate_residuals!(out, ũ, u₀, u₁, α, ρ, internalnorm)
    out
end

"""
    calculate_residuals(u₀, u₁, α, ρ)

Calculate element-wise residuals
```math
\frac{u₁-u₀}{α+\max{|u₀|,|u₁|}*ρ}.
```
"""
@inline @muladd function calculate_residuals(u₀, u₁, α, ρ, internalnorm)
    @. (u₁ - u₀) / (α + max(internalnorm(u₀), internalnorm(u₁)) * ρ)
end

@inline @muladd function calculate_residuals(u₀::Array{T}, u₁::Array{T}, α::T,
                                             ρ::Real, internalnorm) where {T<:Number}
    out = similar(u₀)
    calculate_residuals!(out, u₀, u₁, α, ρ, internalnorm)
    out
end

macro swap!(x,y)
  quote
    local tmp = $(esc(x))
    $(esc(x)) = $(esc(y))
    $(esc(y)) = tmp
  end
end
