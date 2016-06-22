
immutable CurvePt
    pos::VecSE2 # global position and orientation
    s::Float64  # distance along the curve
    k::Float64  # curvature
    kd::Float64 # derivative of curvature
end

Vec.lerp(a::CurvePt, b::CurvePt, t::Float64) = CurvePt(lerp(a.pos, b.pos, t), a.s + (b.s - a.s)*t, a.k + (b.k - a.k)*t, a.kd + (b.kd - a.kd)*t)

############

typealias Curve Vector{CurvePt}

"""
    get_lerp_time(A::VecE2, B::VecE2, Q::VecE2)
Get lerp time t∈[0,1] such that lerp(A, B) is as close as possible to Q
"""
function get_lerp_time(A::VecE2, B::VecE2, Q::VecE2)

    a = Q - A
    b = B - A
    c = proj(a, b, VecE2)

    if b.x != 0.0
        t = c.x / b.x
    else
        t = c.y / b.y
    end

    clamp(t, 0.0, 1.0)
end
get_lerp_time(A::CurvePt, B::CurvePt, Q::VecSE2) = get_lerp_time(convert(VecE2, P₀.pos), convert(VecE2, P₁.pos), convert(VecE2, Q))


immutable CurveIndex
    i::Int     # index in curve, ∈ [1:length(curve)-1]
    t::Float64 # ∈ [0,1] for linear interpolation
end
Base.getindex(curve::Curve, ind::CurveIndex) = lerp(curve[ind.i], curve[ind.i+1], ind.t)

function index_closest_to_point(curve::Curve, target::AbstractVec)

    a = 1
    b = length(curve)
    c = div(a+b, 2)

    @assert(length(curve) ≥ b)

    sqdist_a = abs2(curve[a].pos - target)
    sqdist_b = abs2(curve[b].pos - target)
    sqdist_c = abs2(curve[c].pos - target)

    while true
        if b == a
            return a
        elseif b == a + 1
            return sqdist_b < sqdist_a ? b : a
        elseif c == a + 1 && c == b - 1
            if sqdist_a < sqdist_b && sqdist_a < sqdist_c
                return a
            elseif sqdist_b < sqdist_a && sqdist_b < sqdist_c
                return b
            else
                return c
            end
        end

        left = div(a+c, 2)
        sqdist_l = abs2(curve[left].pos - target)

        right = div(c+b, 2)
        sqdist_r = abs2(curve[right].pos - target)

        if sqdist_l < sqdist_r
            b = c
            sqdist_b = sqdist_c
            c = left
            sqdist_c = sqdist_l
        else
            a = c
            sqdist_a = sqdist_c
            c = right
            sqdist_c = sqdist_r
        end
    end

    error("index_closest_to_point reached unreachable statement")
end

"""
    get_curve_index(curve::Curve, s::Float64)
Return the CurveIndex for the closest s-location on the curve
"""
function get_curve_index(curve::Curve, s::Float64)

    if s ≤ 0.0
        return CurveIndex(1,0.0)
    elseif s ≥ curve[end].s
        return CurveIndex(length(curve)-1,1.0)
    end

    a = 1
    b = length(curve)

    fa = curve[a].s - s
    fb = curve[b].s - s

    n = 1
    while true
        if b == a+1
            return a + -fa/(fb-fa)
        end

        c = div(a+b, 2)
        fc = curve[c].s - s
        n += 1

        if sign(fc) == sign(fa)
            a, fa = c, fc
        else
            b, fb = c, fc
        end
    end

    error("get_curve_index failed for s=$s")
end

"""
    get_curve_index(ind::CurveIndex, curve::Curve, Δs::Float64)
Return the CurveIndex at ind's s position + Δs
"""
function get_curve_index(ind::CurveIndex, curve::Curve, Δs::Float64)

    L = length(curve)
    ind_lo, ind_hi = ind.i, ind.i+1

    s_lo = curve[ind_lo].s
    s_hi = curve[ind_hi].s
    s = lerp(s_lo, s_hi, ind.t)

    if Δs ≥ 0.0

        if s + Δs > s_hi && ind_hi < L
            while s + Δs > s_hi && ind_hi < L
                Δs -= (s_hi - s)
                s = s_hi
                ind_lo += 1
                ind_hi += 1
                s_lo = curve[ind_lo].s
                s_hi = curve[ind_hi].s
            end
        else
            Δs = s + Δs - s_lo
        end

        t = Δs/(s_hi - s_lo)
        CurveIndex(ind_lo, t)
    else
        if s + Δs < s_lo  && ind_lo > 1
            while s + Δs < s_lo  && ind_lo > 1
                Δs += (s - s_lo)
                s = s_lo
                ind_lo -= 1
                ind_hi -= 1
                s_lo = curve[ind_lo].s
                s_hi = curve[ind_hi].s
            end
        else
            Δs = s + Δs - s_lo
        end

        t = 1.0 - Δs/(s_hi - s_lo)
        CurveIndex(ind_lo, t)
    end
end

"""
    CurveProjection
The result of a point projected to a Curve
"""
immutable CurveProjection
    ind::CurveIndex
    t::Float64 # lane offset
    ϕ::Float64 # lane-relative heading [rad]
end

"""
    Vec.proj(posG::VecSE2, curve::Curve)
Return a CurveProjection obtained by projecting posG onto the curve
"""
function Vec.proj(posG::VecSE2, curve::Curve)

    ind = index_closest_to_point(curve, posG)::Int

    # 2 - interpolate between points
    curveind = CurveIndex(0,NaN)
    footpoint = VecSE2(NaN, NaN, NaN)
    d = NaN

    if ind > 1 && ind < length(curve)
        t_lo = get_lerp_time( curve[ind-1], curve[ind],   posG )
        t_hi = get_lerp_time( curve[ind],   curve[ind+1], posG )

        p_lo = lerp( curve[ind-1].pos, curve[ind].pos,   t_lo )
        p_hi = lerp( curve[ind].pos,   curve[ind+1].pos, t_hi )

        d_lo = hypot( p_lo - posG )
        d_hi = hypot( p_hi - posG )

        if d_lo < d_hi
            footpoint = p_lo
            d = d_lo
            curveind = CurveIndex(ind-1, t_lo)
        else
            footpoint = p_hi
            d = d_hi
            curveind = CurveIndex(ind, t_hi)
        end
    elseif ind == 1
        t = get_lerp_time( curve[1], curve[2], posG )
        footpoint = lerp( curve[1].pos, curve[2].pos, t)
        d = hypot(footpoint - posG)
        curveind = CurveIndex(ind, t)
    else # ind == length(curve)
        t = get_lerp_time( curve[end-1], curve[end], posG )
        footpoint = lerp( curve[end-1].pos, curve[end].pos, t)
        d = hypot(footpoint - posG)
        curveind = CurveIndex(ind-1, t)
    end

    # 3 - compute frenet value
    dyaw = _mod2pi2( atan2( posG - footpoint ) - posG.θ )

    on_left_side = abs(_mod2pi2(dyaw - pi/2)) < abs(_mod2pi2(dyaw - 3pi/2))
    d *= on_left_side ? 1.0 : -1.0 # left side is positive, right side is negative

    ϕ = _mod2pi2(posG.θ-footpoint.θ)

    CurveProjection(curveind, d, ϕ)
end