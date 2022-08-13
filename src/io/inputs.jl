"""
    load_domain(path::String, rcp::Int64)
    load_domain(path::String, rcp::String)

Load domain specification from data package.

# Arguments
- path : location of data package
- rcp : RCP scenario to run
"""
function load_domain(path::String, rcp::String)::Domain
    domain_name::String = basename(path)
    if length(domain_name) == 0
        domain_name = basename(dirname(path))
    end

    conn_path::String = joinpath(path, "connectivity/")
    site_data::String = joinpath(path, "site_data")

    dhw::String = joinpath(path, "DHWs", "dhwRCP$(rcp).mat")

    site_path::String = joinpath(site_data, "$(domain_name).gpkg")
    init_coral_cov::String = joinpath(site_data, "coral_cover.mat")
    wave::String = joinpath(path, "waves/wave_RCP$(rcp).mat")

    return Domain(
        domain_name,
        rcp,
        site_path,
        "site_id",
        "reef_siteid",
        init_coral_cov,
        conn_path,
        dhw,
        wave
    )
end
function load_domain(path::String, rcp::Int)::Domain
    return load_domain(path, "$rcp")
end


"""
    load_scenarios(domain::Domain, filepath::String)::DataFrame

Load and pre-process scenario values.
Parameters intended to be of Integer type or casted as such.
"""
function load_scenarios(domain::Domain, filepath::String)::DataFrame
    df = CSV.read(filepath, DataFrame, comment="#")

    if "RCP" in names(df)
        df = df[!, Not("RCP")]
    end

    bnds = domain.model[:bounds]

    p_types = domain.model[:ptype]
    for (i, dt) in enumerate(p_types)
        if dt == "integer"
            df[!, i] .= map_to_discrete.(df[!, i], bnds[i][2])
        end
    end

    return df
end
