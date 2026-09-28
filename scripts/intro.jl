using DrWatson
@quickactivate "rhythmic_complexity"

# Here you may include files from the source directory
include(srcdir("complexity.jl"))
include(srcdir("mirtool.jl"))
include(srcdir("spotifeatures.jl"))
include(srcdir("applefeatures.jl"))
println(
"""
Currently active project is: $(projectname())

Path of active project: $(projectdir())
"""
)
# Complexity.main(datadir("exp_raw","polyedc"))
# Complexity.main(datadir("exp_raw","polybpm"))
# Complexity.main(datadir("exp_raw","toytracks");trim=true)
#Complexity.main(datadir("exp_raw","tracks");trim=true,method="spectrum",overwrite=true)
#Complexity.main(datadir("exp_raw","spotify_previews");trim=false,method="spectrum",overwrite=true)
#Complexity.main(datadir("exp_raw","polyrhythms"),trim=true,overwrite=true,method="spectrum")
#Complexity.main(datadir("exp_raw","polyrhythms"),overwrite=true,method="matlab")
# Complexity.main(datadir("exp_raw","classif");overwrite=true)
#Complexity.main(datadir("exp_raw","polyrhythms");example="irregular_bpm_KS.wav")
#Mirtool.extract_MIR_features(datadir("exp_raw","polyrhythms"),overwrite=false)
#Complexity.main(datadir("exp_raw","friends");trim=false,method="spectrum",overwrite=true)

#Complexity.main(datadir("exp_raw","trol");trim=true,method="spectrum")
#Complexity.main(datadir("exp_raw","trol");trim=false,method="spectrum")
#Mirtool.extract_MIR_features(datadir("exp_raw","trol");trim=true)
#Mirtool.scatter_mirfeature("Pulse Clarity",datadir("exp_raw","trol");trim=true)

#Complexity.main(datadir("exp_raw","toy_spotify_previews");trim=true)
#Mirtool.extract_MIR_features(datadir("exp_raw","toy_spotify_previews");trim=true)
#Mirtool.scatter_mirfeature("Pulse Clarity",datadir("exp_raw","toy_spotify_previews");trim=true)

#Complexity.main(datadir("exp_raw","friends");trim=true,method="spectrum")
#Mirtool.extract_MIR_features(datadir("exp_raw","friends");trim=false)
#Mirtool.scatter_mirfeature("Pulse Clarity",datadir("exp_raw","friends");trim=true)

#Complexity.main(datadir("exp_raw","spotify_previews");trim=false,overwrite=true)
#Mirtool.scatter_mirfeature("Pulse Clarity",datadir("exp_raw","spotify_previews");trim=true,method="spectrum")


#Mirtool.extract_MIR_features(datadir("exp_raw","toytracks");trim=true)


#Mirtool.extract_MIR_features(datadir("exp_raw","tracks");trim=false)

#Mirtool.extract_MIR_features(datadir("exp_raw","spotify_previews");trim=true)

#Mirtool.extract_MIR_features(datadir("exp_raw","spotify_previews"))

#Mirtool.extract_MIR_features(datadir("exp_raw","toy_spotify_previews");trim=true)
#Spotifeatures.compare_with_spotify("spotify_previews";trim=false)
#Spotifeatures.artist_genres_boxplots(datadir("exp_raw","spotify_previews");trim=false)
#Spotifeatures.artist_genres_scatter("Pulse Clarity",datadir("exp_raw","spotify_previews");trim=false,method="spectrum")
#Spotifeatures.artist_genres_scatter("Pulse Clarity",datadir("exp_raw","tracks");trim=false,method="spectrum")

#Complexity.main.(datadir.("exp_raw",["friends","spotify_previews","tracks"]);trim=false,overwrite=true)
#Mirtool.scatter_multidataset("Pulse Clarity",["spotify_previews","friends","tracks"];trim=false,method="spectrum")

#Complexity.main.(datadir.("exp_raw",["friends","spotify_previews","tracks"]);trim=true,overwrite=true)
#Complexity.main.(datadir("exp_raw","tracks");trim=true,overwrite=true)
#Mirtool.scatter_multidataset("Pulse Clarity",["spotify_previews","friends","tracks"];trim=true,method="spectrum")

#Spotifeatures.artist_genres_scatter("Pulse Clarity",datadir("exp_raw","friends");trim=false,method="spectrum")
#Spotifeatures.artist_genres_scatter("Pulse Clarity",datadir.("exp_raw",["friends","spotify_previews","tracks"]);trim=false,method="spectrum")

#Complexity.getcomplexity(datadir("exp_raw","polyrhythms","2_2_bpm_KS.wav");plot=true,trim=true)
#Complexity.getcomplexity(datadir("exp_raw","polyrhythms","irregular_bpm_KS.wav");plot=true,trim=true)

#Complexity.getcomplexity(papersdir("slides","src","dancing_queen.mp3");plot=true,trim=false)
#Complexity.getcomplexity(papersdir("slides","src","sad_sorrowful_love.mp3");plot=true,trim=false)
#Complexity.getcomplexity(papersdir("slides","src","you_are_the_music.mp3");plot=true,trim=false)
