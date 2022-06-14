using Pkg
Pkg.activate("RunDSO")
using CSV
using DataFrames
using Random
using Distributions


DA_factor_index = 0.9858

hour_factor_high = 2.293998
DA_factor_high = 1.54556
Solar_factor_high = 0.000402
Wind_factor_high = 0.003225


function Index(df)
    df.Index_Price = DA_factor_index * df.DA_Price
    return df
end

function High(df)
    df.High_Price = hour_factor_high * df.hour + DA_factor_high * df.DA_Price + Solar_factor_high * df.Solar + Wind_factor_high * df.Wind
    return df
end
    
NewPath = "NewData/"
OldPath = "data/"
 
Solar_df = CSV.read(joinpath(NewPath, "solarHourly.csv"), DataFrame)
Wind_df = CSV.read(joinpath(NewPath, "windHourly.csv"), DataFrame)
ED_price_df = CSV.read(joinpath(OldPath, "ED_price_2030.csv"), DataFrame)
Low_df = CSV.read(joinpath("regdata/ID_Low.csv"), DataFrame)

ED_price_df[!,"hour"] = repeat((1:24), 365)
ED_price_df = ED_price_df[!, [1,3,2]]
rename!(ED_price_df, "price" => "DA_Price")
ED_price_df[!, "Solar"] = Solar_df[!,1]
ED_price_df[!, "Wind"] = Wind_df[!,1]
ED_price_df = Index(ED_price_df)
ED_price_df = High(ED_price_df)
ED_price_df

Low_df[!, 4]

ED_price_df.Low_Price = Low_df[!, 4]
CSV.write("ID_price_calc1.csv", ED_price_df)
