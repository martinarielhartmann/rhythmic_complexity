module Applefeatures
using CSV,DataFrames,DrWatson
function process_fs_genres()
    df = getfsdataset()
    rename!(df,:audioFilename => :trackID,:Genre => :artist_genres)
    df = df[:,[:trackID,:artist_genres]]
    CSV.write(datadir("exp_raw","friends_spotify_features.csv"),df)
end
getfsdataset() = CSV.read(datadir("exp_raw","friends_dataset.csv"),DataFrame)
end
