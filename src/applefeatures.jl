module Applefeatures
using CSV,DataFrames,DrWatson
include(srcdir("utils.jl"))
function process_fs_genres()
    df = getfsdataset()
    rename!(df,:audioFilename => :trackID,:Genre => :artist_genres)
    df = df[:,[:trackID,:artist_genres]]
    CSV.write(datadir("exp_raw","friends_apple_features.csv"),df)
end
function get_df_apple(foldername)
    df = CSV.read(datadir("exp_raw","friends_apple_features.csv"),DataFrame)
    df.trackID = last.(splitpath.(Utils.removextension.(df.trackID)))
    df.trackID=map(x-> x[4:end],df.trackID)
    df.trackID[first.(df.trackID) .== '_'] = map(x->x[2:end],df.trackID[first.(df.trackID) .== '_'])
    df.trackID = map(x-> replace(x,"PrePost_"=>""),df.trackID)
df.trackID = replace.(df.trackID,
    r"^\d{2,3}_" => "",
    r"_n$" => ""
)
    return df
end
getfsdataset() = CSV.read(datadir("exp_raw","friends_dataset.csv"),DataFrame)
end
