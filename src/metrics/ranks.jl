"""
    _get_ranks(rs::ResultSet, intervention::Int64; kwargs...)

Extracts results for a specific intervention (seeding [1] or shading [2])
"""
function _get_ranks(rs::ResultSet, intervention::Int64; kwargs...)
    return slice_results(rs.ranks[intervention=intervention]; kwargs...)
end

"""
    _collate_ranks(rs, selected)

Collates ranks into seed/shade ranking results into a common structure.
"""
function _collate_ranks(rs::ResultSet, selected; kwargs...)::NamedDimsArray
    n_steps, n_sites = size(selected)

    ts = timesteps(rs)
    @assert length(ts) == n_steps

    r_ids = rs.site_data.reef_siteid
    if haskey(kwargs, :sites)
        r_ids = r_ids[kwargs[:sites]]
    end

    if length(r_ids) != n_sites
        @warn "Length of reef ids do not match number of sites"
    end

    return NamedDimsArray(selected; zip((:timesteps, :sites, :scenarios), (ts, r_ids, 1:size(selected, 3)))...)
end


"""
    seed_ranks(rs::ResultSet; kwargs...)

# Arguments
- rs : ResultSet
- kwargs : named dimensions to slice across

# Returns
NamedDimsArray[timesteps, sites, scenarios]

# Example
```julia
ADRIA.metrics.seed_ranks(rs; timesteps=1:10, scenarios=3:5)
```
"""
function seed_ranks(rs::ResultSet; kwargs...)
    selected = _get_ranks(rs, 1; kwargs...)
    return _collate_ranks(rs, selected; kwargs...)
end

"""
    top_n_seeded_sites(rs::ResultSet, n::Int64; kwargs...)

Get the top n seeded sites over time by their unique site id.
Lower rank values are better (e.g., 1 = first choice)

# Arguments
- rs : ResultSet
- n : `n` sites to retrieve
- kwargs : dimensions to slice across

# Returns
NamedDimsArray[sites, [Site Index, Unique ID, Rank], scenarios]
"""
function top_n_seeded_sites(rs::ResultSet, n::Int64; kwargs...)
    ranked_sites = seed_ranks(rs; kwargs...)

    r_ids = rs.site_data.reef_siteid
    min_rank = length(r_ids) + 1

    c_ranks = mean(ranked_sites, dims=1)
    top_sites = Array{Union{String,Int32,Float32,Missing}}(undef, n, 3, size(ranked_sites, 3))
    for scen in axes(ranked_sites, 3)
        flat = vec(c_ranks[1, :, scen])

        idx = partialsortperm(flat, 1:n)

        rank_score = flat[idx]
        if all(rank_score .== min_rank)
            top_sites[:, :, scen] .= missing
            continue
        end

        top_sites[:, 1, scen] .= Int32.(idx)
        top_sites[:, 2, scen] .= r_ids[idx]
        top_sites[:, 3, scen] .= rank_score
    end

    return NamedDimsArray(top_sites, (:sites, :site_ranks, :scenarios))
end

"""
    shade_ranks(rs::ResultSet; kwargs...)

# Arguments
- rs : ResultSet
- kwargs : named dimensions to slice across

# Returns
NamedDimsArray[timesteps, sites, scenarios]

# Example
```julia
ADRIA.metrics.shade_ranks(rs; timesteps=1:10, scenarios=3:5)
```
"""
function shade_ranks(rs::ResultSet; kwargs...)
    selected = _get_ranks(rs, 2; kwargs...)
    return _collate_ranks(rs, selected; kwargs...)
end

"""
    top_N_sites(rs::ResultSet; N::Int64; metric::relative_cover)
    top_N_sites(data::AbstractArray{Real}, N::Int64; stat=mean)

Return the top `N` sites according to the provided metric (defaulting to `mean` of `relative_cover`).


# Arguments
- rs : ResultSet
- N : No. of best performing sites to be selected
- metric : metric to use to order sites from best to worst,
           must take ResultSet as input
- stat : summary statistic to use for comparison (default: mean)

# Returns
NamedDimsArray[:scenarios,:site_ids], where `site_ids` indicates order of site ranking as well.

# Example
```julia
ADRIA.metrics.top_N_sites(rs, 5)
ADRIA.metrics.top_N_sites(rs, 5; metric=ADRIA.metric.relative_cover)
ADRIA.metrics.top_N_sites(rs, 5; metric=ADRIA.metric.relative_cover, stat=median)
```
"""
function top_N_sites(rs::ResultSet, N::Int64; metric=relative_cover, stat=mean)::NamedDimsArray
    return top_N_sites(metric(rs), N; stat=stat)
end
function top_N_sites(data::AbstractArray{<:Real}, N::Int64; stat=mean)
    stat_m = dropdims(stat(data, dims=:timesteps), dims=:timesteps)

    top_N_sites = zeros(Int64, size(stat_m, :scenarios), N)
    for scen in axes(stat_m, :scenarios)
        # sort each scenario according to metric and get indexes
        inds = sortperm(stat_m[:, scen], rev=true)
        top_N_sites[scen, :] = inds[1:N]
    end

    return NamedDimsArray(top_N_sites, (:scenarios, :site_ids))
end
