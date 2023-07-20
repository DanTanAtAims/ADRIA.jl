using Distances
using Clustering


"""
    complexity(x::AbstractMatrix{T})::AbstractMatrix{Float64} where {T <: Real}

Compute Complexity (CE) of an Matrix `x` of shape \$T ⋅ S\$, where \$T\$ is total number of
time steps and \$S\$ is number of scenarios.

# Arguments
- `x` : series matrix of shape \$T ⋅ S\$

# Return
Vector of \$N\$ elements

# Examples
```julia-repl
julia> CE([[1; 2; 3] [1; 3; 4]))
Vector{Float64}:
 2
 5
"""
function complexity(x::AbstractMatrix{T})::Vector{Float64} where {T<:Real}
    return vec(sqrt.(sum(diff(Matrix(x), dims=1) .^ 2, dims=1)))
end

"""
    correlation_factor(ce_i::T, ce_j::T)::Float64 where {T<:Real}

Compute Correlation Factor (CF) between two time series complexities `ce_i` and `ce_j`.

# Arguments
- `ce_i` : Time series `i`
- `ce_j` : Time series `j`

# Returns
Float64

# Examples
```julia-repl
julia> ce = CE([[1; 2; 3] [1; 3; 4]))
julia> CF(ce[1], ce[2])
Float64:
 2.5
"""
function correlation_factor(ce_i::T, ce_j::T)::Float64 where {T<:Real}
    return max(ce_i, ce_j) / min(ce_i, ce_j)
end

"""
    complexity_invariance_distance(data::AbstractMatrix{T})::AbstractMatrix{Float64} where {T<:Real}

Compute Complexity Invariance Distance (CID) between every matrix column pairs (`data`) of
shape \$T ⋅ S\$. The distance between every two series is the weighted euclidian distanced
multiplied by the correlation factor, which takes into account the ration between the two
series complexities. Returns a matrix of distances (\$S ⋅ S\$).

# Arguments
- `data` : Matrix of \$T ⋅ S\$, where \$T\$ is total number of time steps and \$S\$ is number of scenarios

# Returns
Matrix of complexity invariance distances
"""
function complexity_invariance_distance(data::AbstractMatrix{T})::AbstractMatrix{Float64} where {T<:Real}
    ce = complexity(data)

    # Create empty Matrix
    data_size = size(data, 2)
    cid_matrix::AbstractMatrix{Float64} = zeros(data_size, data_size)

    # [1, 1/2, 1/3, ..., 1/n]
    weights = sqrt.(1 ./ (1:size(data, 1)))

    # Iterate over data matrix to compute CID (Complexity Invariance Distance)
    for i in axes(data, 2)
        for j in axes(data, 2)
            ed = weuclidean(data[:, i], data[:, j], weights)
            cf = correlation_factor(ce[i], ce[j])

            # Complexity Invariance Distance
            cid = ed * cf
            cid_matrix[i, j] = cid
            cid_matrix[j, i] = cid
        end
    end

    return cid_matrix
end

"""
    time_series_clustering(data::AbstractMatrix{T}, n_clusters::Int64)::Vector{Int64} where {T<:Real}

Hierarchical clustering between \$S\$ scenarios with \$T\$ time steps each.

# Arguments
- `data` : Matrix of \$T ⋅ S\$, where \$T\$ is total number of time steps and \$S\$ is
  number of scenarios
- `n_clusters` : Number of clusters determined _a priori_.

# Returns
Vector of cluster ids indicating which cluster each scenario belongs to.

# References
1. Steinmann, P., Auping, W.L., Kwakkel, J.H., 2020.
   Behavior-based scenario discovery using time series clustering.
   Technological Forecasting and Social Change 156, 120052.
   https://doi.org/10.1016/j.techfore.2020.120052

2. Batista, G.E.A.P.A., Keogh, E.J., Tataw, O.M., de Souza, V.M.A., 2014.
   CID: an efficient complexity-invariant distance for time series.
   Data Min Knowl Disc 28, 634-669.
   https://doi.org/10.1007/s10618-013-0312-3
"""
function time_series_clustering(data::AbstractMatrix{T}, n_clusters::Int64)::Vector{Int64} where {T<:Real}
    # Compute CID Distance Matrix
    distances = complexity_invariance_distance(data)

    # Create dendogram using distantes matrix
    dendogram = hclust(distances, linkage=:average)

    # Hierarchical clustering with n_clusters clusters
    return cutree(dendogram, k=n_clusters)
end
function time_series_clustering(result_set::ResultSet, data::AbstractMatrix{T}, n_clusters::Int64)::Vector{Int64} where {T<:Real}
    # Find sites with k > 0.0
    non_null_sites = result_set.site_data.k .> 0.0
    filtered_data = data[:, non_null_sites]

    # Apply time series cluster for filtered data
    clusters = time_series_clustering(filtered_data, n_clusters)

    # Assign cluster 0 for filtered sites to use same indexing as the input data
    return [site != 0 ? popfirst!(clusters) : 0 for site in non_null_sites]
end