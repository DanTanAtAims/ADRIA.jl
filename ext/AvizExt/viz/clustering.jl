"""
    ts_cluster(data::AbstractMatrix, clusters::Vector{Int64}; fig_opts::Dict=Dict(), axis_opts::Dict=Dict())
    ts_cluster!(g::Union{GridLayout,GridPosition}, data::AbstractMatrix, clusters::Vector{Int64}; axis_opts::Dict=Dict())

Visualize clustered time series of scenarios.

- `data` : Matrix of scenario data
- `clusters` : Vector of numbers corresponding to clusters

# Returns
Figure
"""
function ADRIA.viz.ts_cluster(data::AbstractMatrix, clusters::Vector{Int64}; fig_opts::Dict=Dict(), axis_opts::Dict=Dict())
    f = Figure(; fig_opts...)
    g = f[1, 1] = GridLayout()

    ADRIA.viz.ts_cluster!(g, data, clusters; axis_opts=axis_opts)

    return f
end
function ADRIA.viz.ts_cluster!(g::Union{GridLayout,GridPosition}, data::AbstractMatrix, clusters::Vector{Int64}; axis_opts::Dict=Dict())
    # Ensure last year is always shown in x-axis
    xtick_vals = get(axis_opts, :xticks, _time_labels(timesteps(data)))
    xtick_rot = get(axis_opts, :xticklabelrotation, 2 / π)
    ax = Axis(
        g[1, 1],
        xticks=xtick_vals,
        xticklabelrotation=xtick_rot;
        axis_opts...
    )

    # Filter clusters and data for non-zero clusters
    clusters_filtered = filter(c -> c != 0, clusters)
    data_filtered = data[:, clusters .> 0]
    
    # Compute cluster colors
    clusters_colors = _clusters_colors(clusters_filtered)
    unique_cluster_colors = unique(clusters_colors)
    
    leg_entry = Any[]
    for clst in unique(clusters_filtered)
        cluster_color = _cluster_color(unique_cluster_colors, clusters_filtered, clst)
        
        push!(leg_entry, series!(ax, data_filtered[:, clusters_filtered .== clst]', solid_color=cluster_color))
    end

    n_clusters = length(unique(clusters_filtered))
    Legend(g[1,2], leg_entry, "Cluster " .* string.(1:n_clusters), framevisible=false)

    return g
end

"""
    ts_spatial_cluster(rs::Union{Domain,ResultSet}, data::AbstractMatrix, clusters::Vector{Int64}; opts::Dict=Dict(), fig_opts::Dict=Dict(), axis_opts::Dict=Dict())
    ts_spatial_cluster!(g, rs, data, clusters; opts::Dict=Dict(), axis_opts::Dict=Dict())

Visualize clustered time series for each site and map.

- `rs` : ResultSet
- `data` : Matrix of scenario data
- `clusters` : Vector of numbers corresponding to clusters

# Returns
Figure
"""
function ADRIA.viz.ts_spatial_cluster(rs::Union{Domain,ResultSet}, data::AbstractMatrix, 
    clusters::Vector{Int64}; opts::Dict=Dict(), fig_opts::Dict=Dict(), 
    axis_opts::Dict=Dict())

    f = Figure(; fig_opts...)
    g = f[1, 1] = GridLayout()
    ADRIA.viz.ts_spatial_cluster!(g, rs, data, clusters; opts=opts, axis_opts=axis_opts)

    return f
end
function ADRIA.viz.ts_spatial_cluster!(g::Union{GridLayout,GridPosition}, 
    rs::Union{Domain,ResultSet}, data::AbstractMatrix, clusters::Vector{Int64}; 
    opts::Dict=Dict(), axis_opts::Dict=Dict())

    opts[:highlight] = get(opts, :highlight, _clusters_colors(clusters))

    d = collect(dropdims(mean(data, dims=:timesteps), dims=:timesteps))
    ADRIA.viz.map!(g, rs, d; opts=opts)

    return g
end

"""
    _cluster_colors(clusters::Vector{Int64})

Vector of cluster colors.

- `clusters` : Vector of numbers corresponding to clusters

# Returns
Vector{RGBA{Float32}}
"""
function _clusters_colors(clusters::Vector{Int64})::Vector{RGBA{Float32}}
    # Number of non-zero clusters
    n_clusters = length(unique(filter(cluster -> cluster != 0, clusters)))

    # Vector of clusters colors for non-zero clusters
    clusters_colors = categorical_colors(:seaborn_bright, n_clusters)

    # Assign color "black" to cluster == 0
    rgba_black = parse(RGBA{Float32}, "transparent")
    return [cluster == 0 ? rgba_black : clusters_colors[cluster] for cluster in clusters]
end

"""
    _cluster_color(clusters_colors::Vector{RGBA{FLoat32}}, clusters::Vector{Int64}, cluster::Int64)

Vector of cluster colors.

- `clusters_colors` : 
- `clusters` : Vector of numbers corresponding to clusters
- `cluster` : 

# Returns
Vector
"""
function _cluster_color(unique_cluster_colors::Vector{RGBA{Float32}}, clusters::Vector{Int64}, 
    cluster::Int64)
    # Number of scenarios on that cluster
    n_scens = count(clusters .== cluster)

    # Compute line weight
    color_weight = max(min((1.0 / (n_scens * 0.05)), 0.6), 0.1)

    return (unique_cluster_colors[cluster], color_weight)
end