"""Functions and methods to produce location-level summaries."""


"""
    per_site(metric, data::NamedDimsArray)

Get metric results applied to the site-level at indicated time (or across timesteps).

# Arguments
- metric : Any function (nominally from the Statistics package) to be applied to `data`
- data : Data set to apply metric to
- timesteps : timesteps to apply `metric` across

# Returns
Named Vector of \$N\$ elements, where \$N\$ is the number of sites.
"""
function per_site(metric, data::NamedDimsArray)::NamedDimsArray
    ndims(data) > 3 ? ArgumentError("site level metrics only possible for a maximum of 3 dimensions") : true

    # Get length of timestep dimension directly
    #   `map` erroneously extracts every single element from the NamedDimsArray
    #   so we use `tf` to subset the dataset.
    # Use of JuliennedArrays is in an attempt to speed up calculation of summary statistics.
    #   We see a small but still worthwhile improvement in practice.
    #   see: https://stackoverflow.com/a/62040897
    tf = axes(data, :timesteps)
    s::Vector{eltype(data)} = map(metric,
        JuliennedArrays.Slices(data[timesteps=tf], dim(data, :timesteps), dim(data, :scenarios))
    )

    return NamedDimsArray(s, sites=axiskeys(data, :sites))
end
function per_site(metric, data::NamedDimsArray, timesteps::Union{UnitRange,Int64,Vector{Int64}})::NamedDimsArray
    return per_site(metric, data[timesteps=timesteps])
end
