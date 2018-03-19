struct GenericIIF1ConstantCache{vecuType,rhsType,nl_rhsType} <: OrdinaryDiffEqConstantCache
  uhold::vecuType
  rhs::rhsType
  nl_rhs::nl_rhsType
end

struct GenericIIF1Cache{uType,DiffCacheType,rhsType,nl_rhsType,rateType,expType} <: OrdinaryDiffEqMutableCache
  u::uType
  uprev::uType
  dual_cache::DiffCacheType
  tmp::uType
  rhs::rhsType
  nl_rhs::nl_rhsType
  rtmp1::rateType
  fsalfirst::rateType
  expA::expType
  k::rateType
end

u_cache(c::GenericIIF1Cache)    = ()
du_cache(c::GenericIIF1Cache)   = (c.rtmp1,c.fsalfirst,c.k)
dual_cache(c::GenericIIF1Cache) = (c.dual_cache,)

function alg_cache(alg::GenericIIF1,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{false}})
  uhold = Vector{typeof(u)}(1)
  rhs = RHS_IIF_Scalar(f,zero(u),t,t,one(uEltypeNoUnits),p)
  nl_rhs = alg.nlsolve(Val{:init},rhs,uhold)
  GenericIIF1ConstantCache(uhold,rhs,nl_rhs)
end

function alg_cache(alg::GenericIIF1,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{true}})
  tmp = similar(u,indices(u)); rtmp1 = zeros(rate_prototype)
  dual_cache = DiffCache(u,Val{determine_chunksize(u,get_chunksize(alg.nlsolve))})
  A = f.f1
  expA = expm(A*dt)
  rhs = RHS_IIF(f,tmp,t,t,uEltypeNoUnits(1//1),dual_cache,p)
  k = similar(rate_prototype); fsalfirst = similar(rate_prototype)
  nl_rhs = alg.nlsolve(Val{:init},rhs,u)
  GenericIIF1Cache(u,uprev,dual_cache,tmp,rhs,nl_rhs,rtmp1,fsalfirst,expA,k)
end

struct GenericIIF2ConstantCache{vecuType,rhsType,nl_rhsType} <: OrdinaryDiffEqConstantCache
  uhold::vecuType
  rhs::rhsType
  nl_rhs::nl_rhsType
end

struct GenericIIF2Cache{uType,DiffCacheType,rhsType,nl_rhsType,rateType,expType} <: OrdinaryDiffEqMutableCache
  u::uType
  uprev::uType
  dual_cache::DiffCacheType
  tmp::uType
  rhs::rhsType
  nl_rhs::nl_rhsType
  rtmp1::rateType
  fsalfirst::rateType
  expA::expType
  k::rateType
end

u_cache(c::GenericIIF2Cache)    = ()
du_cache(c::GenericIIF2Cache)   = (c.rtmp1,c.fsalfirst,c.k)
dual_cache(c::GenericIIF2Cache) = (c.dual_cache,)

function alg_cache(alg::GenericIIF2,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{false}})
  uhold = Vector{typeof(u)}(1)
  tmp = zero(u)
  rhs = RHS_IIF_Scalar(f,tmp,t,t,uEltypeNoUnits(1//2),p)
  nl_rhs = alg.nlsolve(Val{:init},rhs,uhold)
  GenericIIF2ConstantCache(uhold,rhs,nl_rhs)
end

function alg_cache(alg::GenericIIF2,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{true}})
  tmp = similar(u,indices(u)); rtmp1 = zeros(rate_prototype)
  dual_cache = DiffCache(u,Val{determine_chunksize(u,get_chunksize(alg.nlsolve))})
  A = f.f1
  expA = expm(A*dt)
  k = similar(rate_prototype); fsalfirst = similar(rate_prototype)
  rhs = RHS_IIF(f,tmp,t,t,uEltypeNoUnits(1//2),dual_cache,p)
  nl_rhs = alg.nlsolve(Val{:init},rhs,u)
  GenericIIF2Cache(u,uprev,dual_cache,tmp,rhs,nl_rhs,rtmp1,fsalfirst,expA,k)
end

# Fsal type for exponential RK algorithms
mutable struct ExpRKFsal{rateType}
  lin::rateType
  nl::rateType
end
ExpRKFsal(rate_prototype) = ExpRKFsal(zero(rate_prototype),zero(rate_prototype))
function recursivecopy!(dest::ExpRKFsal, src::ExpRKFsal)
  recursivecopy!(dest.lin, src.lin)
  recursivecopy!(dest.nl, src.nl)
end

struct LawsonEulerCache{uType,rateType,expType} <: OrdinaryDiffEqMutableCache
  u::uType
  uprev::uType
  tmp::uType
  rtmp::rateType
  exphA::expType
end

function alg_cache(alg::LawsonEuler,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{true}})
  if alg.krylov
    exphA = nothing # no caching
  else
    A = f.f1
    if isa(A, DiffEqArrayOperator)
      _A = A.A * A.α.coeff
    else
      _A = full(A)
    end
    exphA = expm(dt*_A)
  end
  LawsonEulerCache(u,uprev,similar(u),zeros(rate_prototype),exphA)
end

u_cache(c::LawsonEulerCache) = ()
du_cache(c::LawsonEulerCache) = (c.rtmp)

struct LawsonEulerConstantCache{expType} <: OrdinaryDiffEqConstantCache 
  exphA::expType
end

function alg_cache(alg::LawsonEuler,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{false}})
  if alg.krylov
    exphA = nothing # no caching
  else
    A = f.f1
    if isa(A, DiffEqArrayOperator)
      _A = A.A * A.α.coeff
    else
      _A = full(A)
    end
    exphA = expm(dt*_A)
  end
  LawsonEulerConstantCache(exphA)
end

struct NorsettEulerCache{uType,rateType,expType} <: OrdinaryDiffEqMutableCache
  u::uType
  uprev::uType
  tmp::uType
  rtmp::rateType
  exphA::expType
  phihA::expType
end

function alg_cache(alg::NorsettEuler,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{true}})
  if alg.krylov
    exphA = nothing # no caching
    phihA = nothing
  else
    A = f.f1
    if isa(A, DiffEqArrayOperator)
      _A = A.A * A.α.coeff
    else
      _A = full(A)
    end
    exphA, phihA = get_etd1_operators(dt, _A)
  end
  NorsettEulerCache(u,uprev,similar(u),zeros(rate_prototype),exphA,phihA)
end

u_cache(c::NorsettEulerCache) = ()
du_cache(c::NorsettEulerCache) = (c.rtmp)

struct NorsettEulerConstantCache{expType} <: OrdinaryDiffEqConstantCache 
  exphA::expType
  phihA::expType
end

function alg_cache(alg::NorsettEuler,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{false}})
  if alg.krylov
    exphA = nothing # no caching
    phihA = nothing
  else
    A = f.f1
    if isa(A, DiffEqArrayOperator)
      _A = A.A * A.α.coeff
    else
      _A = full(A)
    end
    exphA, phihA = get_etd1_operators(dt, _A)
  end
  NorsettEulerConstantCache(exphA, phihA)
end

function get_etd1_operators(h::Real, A::T) where {T <: Number}
  # Use BigFloat to avoid loss of precision
  _hA = big(h) * big(A)
  oneT = one(T)
  _oneT = big(oneT)
  if iszero(_hA)
    exphA = oneT
    phihA = oneT
  else
    _exphA = exp(_hA)
    exphA = T(_exphA)
    phihA = T((_exphA - _oneT) / _hA)
  end
  return exphA, phihA
end
function get_etd1_operators(h::Real, A::Diagonal)
  coeffs = get_etd1_operators.(h, A.diag)
  exphA = Diagonal(map(x -> x[1]), coeffs)
  phihA = Diagonal(map(x -> x[2]), coeffs)
  return exphA, phihA
end
function get_etd1_operators(h::Real, A::AbstractMatrix{T}) where T
  # Use BigFloat to avoid loss of precision
  _hA = big(h) * big.(A)
  hA = T.(_hA)
  exphA = expm(hA)
  _exphA = big.(exphA)
  phihA = T.((_exphA - I) / _hA)
  return exphA, phihA
end

#=
  Fsal separately the linear and nonlinear part, as well as the nonlinear 
  part in the previous time step.
=#
mutable struct ETD2Fsal{rateType}
  lin::rateType
  nl::rateType
  nlprev::rateType
end
ETD2Fsal(rate_prototype) = ETD2Fsal(zero(rate_prototype),zero(rate_prototype),zero(rate_prototype))
function recursivecopy!(dest::ETD2Fsal, src::ETD2Fsal)
  recursivecopy!(dest.lin, src.lin)
  recursivecopy!(dest.nl, src.nl)
  recursivecopy!(dest.nlprev, src.nlprev)
end

struct ETD2ConstantCache{expType} <: OrdinaryDiffEqConstantCache
  exphA::expType
  phihA::expType
  B1::expType
  B0::expType
end

function alg_cache(alg::ETD2,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{false}})
  A = f.f1
  if isa(A, DiffEqArrayOperator)
    _A = A.A * A.α.coeff # .* does not return Diagonal for A.A Diagonal
  else
    _A = full(A)
  end
  exphA, phihA, B1, B0 = get_etd2_operators(dt, _A)
  ETD2ConstantCache(exphA, phihA, B1, B0)
end

struct ETD2Cache{uType,rateType,expType} <: OrdinaryDiffEqMutableCache
  u::uType
  uprev::uType
  utmp::uType
  rtmp1::rateType
  rtmp2::rateType
  exphA::expType
  phihA::expType
  B1::expType
  B0::expType
end

function alg_cache(alg::ETD2,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{true}})
  A = f.f1
  if isa(A, DiffEqArrayOperator)
    _A = A.A * A.α.coeff # .* does not return Diagonal for A.A Diagonal
  else
    _A = full(A)
  end
  exphA, phihA, B1, B0 = get_etd2_operators(dt, _A)
  ETD2Cache(u,uprev,zero(u),zero(rate_prototype),zero(rate_prototype),exphA,phihA,B1,B0)
end

# TODO: what should these be?
u_cache(c::ETD2Cache) = ()
du_cache(c::ETD2Cache) = (c.rtmp1,c.rtmp2)

#=
  Computes the update coeffiicents for the time stepping

    u_n+2 = exp(hA)*u_n+1 + h(B1*N_n+1 + B0*N_n)
  
  Also compute phi(hA) for the initial ETD1 step.

  For scalar or Diagonal A, handles the singularity at A=0.
  TODO: use expm1 for A close to 0?
=#
function get_etd2_operators(h::Real, A::T) where {T <: Number}
  # Use BigFloat to avoid loss of precision
  _hA = big(h) * big(A)
  oneT = one(T)
  _oneT = big(oneT)
  if iszero(_hA)
    exphA = oneT
    phihA = oneT
    B1 = 1.5 * oneT
    B0 = -0.5 * oneT
  else
    _hA2 = _hA * _hA
    _exphA = exp(_hA)
    exphA = T(_exphA)
    phihA = T((_exphA - _oneT) / _hA) # x - I for scalar x is deprecated
    B1 = T(((_hA + _oneT)*_exphA - _oneT - 2*_hA) / _hA2)
    B0 = T((_oneT + _hA - _exphA) / _hA2)
  end
  return exphA, phihA, B1, B0
end
function get_etd2_operators(h::Real, A::Diagonal)
  coeffs = get_etd2_operators.(h, A.diag)
  exphA = Diagonal(map(x -> x[1], coeffs))
  phihA = Diagonal(map(x -> x[2], coeffs))
  B1 = Diagonal(map(x -> x[3], coeffs))
  B0 = Diagonal(map(x -> x[4], coeffs))
  return exphA, phihA, B1, B0
end
function get_etd2_operators(h::Real, A::AbstractMatrix{T}) where T
  # Use BigFLoat to avoid loss of precision
  _hA = big(h) * big.(A)
  hA = T.(_hA)
  _hA2 = _hA * _hA
  exphA = expm(hA)
  _exphA = big.(exphA)
  phihA = T.((_exphA - I) / _hA)
  B1 = T.(((_hA + I)*_exphA - I - 2*_hA) / _hA2)
  B0 = T.((I + _hA - _exphA) / _hA2)
  return exphA, phihA, B1, B0
end

struct ETDRK4ConstantCache{matType} <: OrdinaryDiffEqConstantCache
  E::matType
  E2::matType
  a::matType
  b::matType
  c::matType
  Q::matType
end

function alg_cache(alg::ETDRK4,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{false}})
  A = f.f1
  if isa(A, DiffEqArrayOperator)
    L = A.A .* A.α.coeff # has special handling if A.A is Diagonal
  else
    L = full(A)
  end
  E,E2,a,b,c,Q = get_etdrk4_oop_operators(dt,L)
  ETDRK4ConstantCache(E,E2,a,b,c,Q)
end

function get_etdrk4_oop_operators(_h,L)
  h = big(_h)
  A = h*L
  _E2 = expm(Float64.(A/2))
  E2 = big.(_E2);
  E = E2*E2
  A = big.(A)
  coeff = h^(-2) * L^(-3)
  A2 = A^2
  if typeof(L) <: Number
    Q = Float64.((E2-1)/L)
    a = Float64.(coeff * (-4 - A + E*(4 - 3A  + A2)))
    b = Float64.(coeff * (2 + A + E*(-2 + A)))
    c = Float64.(coeff * (-4 - 3A - A2 + E*(4-A)))
  else
    Q = Float64.((E2-I)/L)
    a = Float64.(coeff * (-4I - A + E*(4I - 3A  + A2)))
    b = Float64.(coeff * (2I + A + E*(-2I + A)))
    c = Float64.(coeff * (-4I - 3A - A2 + E*(4I-A)))
  end
  Float64.(E),_E2,a,b,c,Q
end

struct ETDRK4Cache{uType,rateType,matType} <: OrdinaryDiffEqMutableCache
  u::uType
  uprev::uType
  tmp::uType
  s1::uType
  tmp2::rateType
  k2::rateType
  k3::rateType
  k4::rateType
  E::matType
  E2::matType
  a::matType
  b::matType
  c::matType
  Q::matType
end

function alg_cache(alg::ETDRK4,u,rate_prototype,uEltypeNoUnits,uBottomEltypeNoUnits,tTypeNoUnits,uprev,uprev2,f,t,dt,reltol,p,calck,::Type{Val{true}})
  A = f.f1
  tmp = similar(u)
  tmp2 = zeros(rate_prototype)
  k2 = zeros(rate_prototype); k3 = zeros(rate_prototype); k4 = zeros(rate_prototype)
  s1 = similar(u)
  if isa(A, DiffEqArrayOperator)
    L = A.A .* A.α.coeff # has special handling if A.A is Diagonal
  else
    L = full(A)
  end
  E,E2,a,b,c,Q = get_etdrk4_operators(dt,L)
  ETDRK4Cache(u,uprev,tmp,s1,tmp2,k2,k3,k4,E,E2,a,b,c,Q)
end

u_cache(c::ETDRK4Cache) = ()
du_cache(c::ETDRK4Cache) = (c.k,c.fsalfirst,c.rtmp)

function get_etdrk4_operators(_h,L)

    @. L .*= _h/2
    _E2 = expm(L)
    E2 = big.(_E2);
    E = E2*E2
    @. L *= 2/_h
    h = big(_h)
    A = h*L

    # TODO: Check if we should big L
    coeff = h^(-2) * L^(-3)

    @inbounds for i in 1:size(E2,1)
        E2[i,i] = E2[i,i] - 1
    end

    tmp = E2/L
    Q = Float64.(tmp)

    @inbounds for i in 1:size(E2,1)
        E2[i,i] = E2[i,i] + 1
    end

    @inbounds for i in 1:size(A,2), j in 1:size(A,1)
        tmp[j,i] = -2I[j,i] + A[j,i]
    end

    tmp2 = E*tmp

    @inbounds for i in 1:size(A,2), j in 1:size(A,1)
        tmp[j,i] = 2I[j,i] + A[j,i] + tmp2[j,i]
    end

    A_mul_B!(tmp2,coeff,tmp)
    b = Float64.(tmp2)

    A2 = A^2

    @inbounds for i in 1:size(A,2), j in 1:size(A,1)
        tmp[j,i] = 4I[j,i] - 3A[j,i]  + A2[j,i]
    end

    A_mul_B!(tmp2,E,tmp)

    @inbounds for i in 1:size(A,2), j in 1:size(A,1)
        tmp[j,i] = -4I[j,i] - A[j,i] + tmp2[j,i]
    end

    A_mul_B!(tmp2,coeff,tmp)
    a = Float64.(tmp2)

    @inbounds for i in 1:size(A,2), j in 1:size(A,1)
        tmp[j,i] = 4I[j,i]-A[j,i]
    end

    A_mul_B!(tmp2,E,tmp)

    @inbounds for i in 1:size(A,2), j in 1:size(A,1)
        tmp[j,i] = -4I[j,i] - 3A[j,i] - A2[j,i] + tmp2[j,i]
    end

    A_mul_B!(tmp2,coeff,tmp)
    c = Float64.(tmp2)

    Float64.(E),_E2,a,b,c,Q
end

function get_etdrk4_operators(_h,_L::Diagonal)

    L = _L.diag

    @. L = _h/2*L
    _E2 = exp.(L)
    E2 = big.(_E2);
    E = E2.*E2
    @. L *= 2/_h
    h = big(_h)
    A = h.*L

    coeff = @. h^(-2) * L^(-3)
    A2 = A.^2

    Q = @. Float64((E2-1)/L)
    a = @. Float64(coeff * (-4 - A + E*(4 - 3A  + A2)))
    b = @. Float64(coeff * (2 + A + E*(-2 + A)))
    c = @. Float64(coeff * (-4 - 3A - A2 + E*(4-A)))

    # Fix zero eigenvalues, use limit equations
    for i in 1:length(Q)
        if L[i] == 0
            Q[i] = _h/2
            tmp = _h/6
            a[i] = tmp
            b[i] = tmp
            c[i] = tmp
        end
    end

    Diagonal(Float64.(E)),Diagonal(Float64.(E2)),Diagonal(a),Diagonal(b),Diagonal(c),Diagonal(Q)
end
