using Pkg
Pkg.activate("RunDSO")

println("Loading required packages: ProgressMeter, CSV, DataFrames, Dates, JuMP, Gurobi.")
using ProgressMeter
using CSV
using DataFrames
using Dates
using JuMP
using Gurobi
println("Loading of packages complete.")

###################
# Terminal ########
###################

    usedayperiod = true
    startday = 1
    lastday = 365
    starthour = 1
    lasthour = 8760
	share_cts = 0.3
	share_res = 0.3
	share_ind = 0.4
    shiftpot_cts = 0.05
    shiftpot_res = 0.05
    shiftpot_ind = 0.1
    workhours = 9:16

    scenarios = collect(1:4)
    scen_chance_dict = Dict()
    scen_chance_dict[1] = 0.40
    scen_chance_dict[2] = 0.2
    scen_chance_dict[3] = 0.15
    scen_chance_dict[4] = 0.25
    # scen_chance_dict[5] = 0.1
    # scen_chance_dict[6] = 0.1

    # scen_multiplier_dict = Dict()
    # scen_multiplier_dict[1] = 1.2
    # scen_multiplier_dict[2] = 1
    # scen_multiplier_dict[3] = 0.8
    # scen_multiplier_dict[4] = 0     
    # # scen_multiplier_dict[5] = 1.1  
    # # scen_multiplier_dict[6] = 0.9

    datapath = "data/"
    newpath = "NewData/"
    inputpath = "Paper1_inputdata/"
    outputpath = "output/sensitivity/"
    IDfile = "ID_price_calc1.csv"
    regpath = "regdata/"

    isworkhour = Dict()
    for i in 0:24
        if i in workhours isworkhour[i] = 1
        else isworkhour[i] = 0
        end
    end
    if usedayperiod == true
        timeperiod = string((startday-1)*24+1)*":"*string((lastday*24))
    else
        timeperiod = string(starthour)*":"*string(lasthour)
    end

    timeperiod_str = replace(string(timeperiod), ":" => "-")

    session_time = String(Dates.format(now(), "dd.mm.HH_MM"))
    mkdir(joinpath(outputpath, session_time * "_" * timeperiod_str))
    outputpath = joinpath(outputpath, session_time * "_" * timeperiod_str)


    println()
    # println("Case >" * case * "< selected.")
    println("Calculating for new load profiles.")
    println()

    include("model/src/Sesam_ptdf_LoadShift.jl")

    using .Sesam

###################
# Data ############
###################
# Read nodes and load from .csv
    println("Reading data from csv...")

	# nodes_df = CSV.read(joinpath(datapath, "nodes.csv"), DataFrame)
    nodes_df_30 = CSV.read(joinpath(newpath, "nodeCoordinates.csv"), DataFrame)
    nodes_df_30 = rename!(nodes_df_30, :node => :id)[:, 1:3]

	# load_df = CSV.read(joinpath(datapath, "load.csv"), DataFrame)
    load_df_30 = CSV.read(joinpath(newpath, "demandHourly.csv"), DataFrame)
    rename!(load_df_30, 1 => :systemload)

    b = CSV.read(joinpath(newpath, "loadShare.csv"),DataFrame)

    for i in 1:nrow(b)
        load_df_30[!, Symbol(b[i, 1])] = repeat([b[i, 2]], 8760)
    end
    #    load_df_30

	exchange_df = CSV.read(joinpath(datapath, "exchange.csv"), DataFrame)

    nodal_hourlycost_df = CSV.read(joinpath(inputpath, "hourly_nodal_RD_cost.csv"), DataFrame)

    nodal_hourlyvolume_df = CSV.read(joinpath(inputpath, "hourly_nodal_RD_volume.csv"), DataFrame)

    marketprice_df = CSV.read(joinpath(inputpath, "ED_price.csv"), DataFrame)

    IDprice_df = CSV.read(joinpath(regpath, IDfile), DataFrame)
                                    
    println("Reading of data complete.")
    println()
    println("Creating dictionaries for costs, volumes and ID price...")


    nod_vol_dict = Dict((nodal_hourlyvolume_df[i, 1] => Dict((j => nodal_hourlyvolume_df[i, j+1]) for j in 1:8760)) for i in 1:nrow(nodal_hourlyvolume_df))
    nod_cost_dict = Dict((nodal_hourlycost_df[i, 1] => Dict((j => nodal_hourlycost_df[i, j+1]) for j in 1:8760)) for i in 1:nrow(nodal_hourlycost_df))
    da_price_dict = Dict(eachrow(marketprice_df))

    ID_indexprice = IDprice_df.Index_Price
    ID_highprice = IDprice_df.High_Price
    ID_lowprice = IDprice_df.Low_Price

###################
# Model setup #####
###################

    println("Preparing nodes...")

    # Create set of nodes
        nodes = Nodes(nodes_df_30, load_df_30, exchange_df, 1000, 1)

        N = nodes.id

    println("Preparation complete.")
    println()

output_shifts_nodal_scen1 = DataFrame(day=Int64[], time=Int64[], node=Int64[], Shift_Up=Float64[], Shift_Dn=Float64[],
    Shift_Up_CM=Float64[], Shift_Dn_CM=Float64[], Shift_Up_ID=Float64[], Shift_Dn_ID=Float64[], 
    Shift_Up_CM_CTS=Float64[], Shift_Dn_CM_CTS=Float64[], Shift_Up_CM_RES=Float64[], Shift_Dn_CM_RES=Float64[], Shift_Up_CM_IND=Float64[], Shift_Dn_CM_IND=Float64[],
    Shift_Up_ID_CTS=Float64[], Shift_Dn_ID_CTS=Float64[], Shift_Up_ID_RES=Float64[], Shift_Dn_ID_RES=Float64[], Shift_Up_ID_IND=Float64[], Shift_Dn_ID_IND=Float64[], 
    New_CM_Load=Float64[], New_Load=Float64[], Original_Load=Float64[], 
    Hourly_Cashflow_Sum=Float64[], Hourly_Cashflow_CM=Float64[], Hourly_Cashflow_ID=Float64[], 
    DA_price=Float64[], ID_price=Float64[], CM_price=Float64[])
CSV.write(joinpath(outputpath, "output_nodal_scen1.csv"), output_shifts_nodal_scen1)
output_shifts_nodal_scen2 = DataFrame(day=Int64[], time=Int64[], node=Int64[], Shift_Up=Float64[], Shift_Dn=Float64[],
    Shift_Up_CM=Float64[], Shift_Dn_CM=Float64[], Shift_Up_ID=Float64[], Shift_Dn_ID=Float64[], 
    Shift_Up_CM_CTS=Float64[], Shift_Dn_CM_CTS=Float64[], Shift_Up_CM_RES=Float64[], Shift_Dn_CM_RES=Float64[], Shift_Up_CM_IND=Float64[], Shift_Dn_CM_IND=Float64[],
    Shift_Up_ID_CTS=Float64[], Shift_Dn_ID_CTS=Float64[], Shift_Up_ID_RES=Float64[], Shift_Dn_ID_RES=Float64[], Shift_Up_ID_IND=Float64[], Shift_Dn_ID_IND=Float64[], 
    New_CM_Load=Float64[], New_Load=Float64[], Original_Load=Float64[], 
    Hourly_Cashflow_Sum=Float64[], Hourly_Cashflow_CM=Float64[], Hourly_Cashflow_ID=Float64[], 
    DA_price=Float64[], ID_price=Float64[], CM_price=Float64[])
CSV.write(joinpath(outputpath, "output_nodal_scen2.csv"), output_shifts_nodal_scen2)
output_shifts_nodal_scen3 = DataFrame(day=Int64[], time=Int64[], node=Int64[], Shift_Up=Float64[], Shift_Dn=Float64[],
    Shift_Up_CM=Float64[], Shift_Dn_CM=Float64[], Shift_Up_ID=Float64[], Shift_Dn_ID=Float64[], 
    Shift_Up_CM_CTS=Float64[], Shift_Dn_CM_CTS=Float64[], Shift_Up_CM_RES=Float64[], Shift_Dn_CM_RES=Float64[], Shift_Up_CM_IND=Float64[], Shift_Dn_CM_IND=Float64[],
    Shift_Up_ID_CTS=Float64[], Shift_Dn_ID_CTS=Float64[], Shift_Up_ID_RES=Float64[], Shift_Dn_ID_RES=Float64[], Shift_Up_ID_IND=Float64[], Shift_Dn_ID_IND=Float64[], 
    New_CM_Load=Float64[], New_Load=Float64[], Original_Load=Float64[], 
    Hourly_Cashflow_Sum=Float64[], Hourly_Cashflow_CM=Float64[], Hourly_Cashflow_ID=Float64[], 
    DA_price=Float64[], ID_price=Float64[], CM_price=Float64[])
CSV.write(joinpath(outputpath, "output_nodal_scen3.csv"), output_shifts_nodal_scen3)
output_shifts_nodal_scen4 = DataFrame(day=Int64[], time=Int64[], node=Int64[], Shift_Up=Float64[], Shift_Dn=Float64[],
    Shift_Up_CM=Float64[], Shift_Dn_CM=Float64[], Shift_Up_ID=Float64[], Shift_Dn_ID=Float64[], 
    Shift_Up_CM_CTS=Float64[], Shift_Dn_CM_CTS=Float64[], Shift_Up_CM_RES=Float64[], Shift_Dn_CM_RES=Float64[], Shift_Up_CM_IND=Float64[], Shift_Dn_CM_IND=Float64[],
    Shift_Up_ID_CTS=Float64[], Shift_Dn_ID_CTS=Float64[], Shift_Up_ID_RES=Float64[], Shift_Dn_ID_RES=Float64[], Shift_Up_ID_IND=Float64[], Shift_Dn_ID_IND=Float64[], 
    New_CM_Load=Float64[], New_Load=Float64[], Original_Load=Float64[], 
    Hourly_Cashflow_Sum=Float64[], Hourly_Cashflow_CM=Float64[], Hourly_Cashflow_ID=Float64[], 
    DA_price=Float64[], ID_price=Float64[], CM_price=Float64[])
CSV.write(joinpath(outputpath, "output_nodal_scen4.csv"), output_shifts_nodal_scen4)
output_DSO_ID_mod_info = DataFrame(timeperiod=String[], termination_status=String[], primal_status=String[], dual_status=String[], objective_value=Float64[], solve_time=Float64[])
CSV.write(joinpath(outputpath, "DSO_ID_mod_info.csv"), output_DSO_ID_mod_info)



# ### TESTING DAY BY DAY

    #     hours = 1:24
    #     dayindex = Int(hours[end]/24)
    #     println("Optimzing for hours " * string(hours) * "...")
    #     av_rd_price_dict = Dict((n => Dict()) for n in N)
    #     for n in N
    #         for t in hours
    #             if nod_vol_dict[n][t] == 0
    #                 av_rd_price_dict[n][t] = 0
    #             else
    #                 av_rd_price_dict[n][t] = nod_cost_dict[n][t]/nod_vol_dict[n][t]
    #             end
    #         end
    #     end

    #     ID_scen_price_dict = Dict(i => Dict() for i in scenarios)
    #     for h in hours 
    #         ID_scen_price_dict[1][h] = ID_indexprice[h]
    #         ID_scen_price_dict[2][h] = ID_highprice[h]
    #         ID_scen_price_dict[3][h] = ID_lowprice[h]
    #         ID_scen_price_dict[4][h] = ID_indexprice[h]
    #     end


        

    #     DSO_ID_mod, ShiftUp, ShiftDn, ShiftUpCM, ShiftDnCM, ShiftUpID, ShiftDnID, ShiftUpCMRes, ShiftUpCMCTS, ShiftUpCMInd, 
    #         ShiftDnCMRes, ShiftDnCMCTS, ShiftDnCMInd, ShiftUpIDCTS, ShiftDnIDCTS, ShiftUpIDRes, ShiftDnIDRes,
    #         ShiftUpIDInd, ShiftDnIDInd, NewCMLoad, ScenarioLoad = DSO_CM_ID_LoadShift(
    #         hours, nodes, ID_scen_price_dict, av_rd_price_dict, share_cts, share_res, share_ind, 
    #         shiftpot_cts, shiftpot_res, shiftpot_ind, isworkhour, scenarios, scen_chance_dict)


    #         output_DSO_ID_mod_info = DataFrame(timeperiod=String[], termination_status=String[], primal_status=String[], dual_status=String[], objective_value=Float64[], solve_time=Float64[])
    #         push!(output_DSO_ID_mod_info, [string(hours) string(termination_status(DSO_ID_mod)) string(primal_status(DSO_ID_mod)) string(dual_status(DSO_ID_mod)) objective_value(DSO_ID_mod) solve_time(DSO_ID_mod)])
    #         CSV.write(joinpath(outputpath, "DSO_ID_mod_info.csv"), output_DSO_ID_mod_info, append=true)
            
    #         output_shifts_nodal_scen1 = DataFrame(day=Int64[], time=Int64[], node=Int64[], Shift_Up=Float64[], Shift_Dn=Float64[],
    #                 Shift_Up_CM=Float64[], Shift_Dn_CM=Float64[], Shift_Up_ID=Float64[], Shift_Dn_ID=Float64[], 
    #                 Shift_Up_CM_CTS=Float64[], Shift_Dn_CM_CTS=Float64[], Shift_Up_CM_RES=Float64[], Shift_Dn_CM_RES=Float64[], Shift_Up_CM_IND=Float64[], Shift_Dn_CM_IND=Float64[],
    #                 Shift_Up_ID_CTS=Float64[], Shift_Dn_ID_CTS=Float64[], Shift_Up_ID_RES=Float64[], Shift_Dn_ID_RES=Float64[], Shift_Up_ID_IND=Float64[], Shift_Dn_ID_IND=Float64[], 
    #                 New_CM_Load=Float64[], New_Load=Float64[], Original_Load=Float64[], 
    #                 Hourly_Cashflow_Sum=Float64[], Hourly_Cashflow_CM=Float64[], Hourly_Cashflow_ID=Float64[], 
    #                 DA_price=Float64[], ID_price=Float64[], CM_price=Float64[])
    #         output_shifts_nodal_scen2 = DataFrame(day=Int64[], time=Int64[], node=Int64[], Shift_Up=Float64[], Shift_Dn=Float64[], 
    #                 Shift_Up_CM=Float64[], Shift_Dn_CM=Float64[], Shift_Up_ID=Float64[], Shift_Dn_ID=Float64[], 
    #                 Shift_Up_CM_CTS=Float64[], Shift_Dn_CM_CTS=Float64[], Shift_Up_CM_RES=Float64[], Shift_Dn_CM_RES=Float64[], Shift_Up_CM_IND=Float64[], Shift_Dn_CM_IND=Float64[],
    #                 Shift_Up_ID_CTS=Float64[], Shift_Dn_ID_CTS=Float64[], Shift_Up_ID_RES=Float64[], Shift_Dn_ID_RES=Float64[], Shift_Up_ID_IND=Float64[], Shift_Dn_ID_IND=Float64[], 
    #                 New_CM_Load=Float64[], New_Load=Float64[], Original_Load=Float64[], 
    #                 Hourly_Cashflow_Sum=Float64[], Hourly_Cashflow_CM=Float64[], Hourly_Cashflow_ID=Float64[], 
    #                 DA_price=Float64[], ID_price=Float64[], CM_price=Float64[])
    #         output_shifts_nodal_scen3 = DataFrame(day=Int64[], time=Int64[], node=Int64[],  Shift_Up=Float64[], Shift_Dn=Float64[],
    #                 Shift_Up_CM=Float64[], Shift_Dn_CM=Float64[], Shift_Up_ID=Float64[], Shift_Dn_ID=Float64[], 
    #                 Shift_Up_CM_CTS=Float64[], Shift_Dn_CM_CTS=Float64[], Shift_Up_CM_RES=Float64[], Shift_Dn_CM_RES=Float64[], Shift_Up_CM_IND=Float64[], Shift_Dn_CM_IND=Float64[],
    #                 Shift_Up_ID_CTS=Float64[], Shift_Dn_ID_CTS=Float64[], Shift_Up_ID_RES=Float64[], Shift_Dn_ID_RES=Float64[], Shift_Up_ID_IND=Float64[], Shift_Dn_ID_IND=Float64[], 
    #                 New_CM_Load=Float64[], New_Load=Float64[], Original_Load=Float64[], 
    #                 Hourly_Cashflow_Sum=Float64[], Hourly_Cashflow_CM=Float64[], Hourly_Cashflow_ID=Float64[], 
    #                 DA_price=Float64[], ID_price=Float64[], CM_price=Float64[])
    #         output_shifts_nodal_scen4 = DataFrame(day=Int64[], time=Int64[], node=Int64[],  Shift_Up=Float64[], Shift_Dn=Float64[],
    #                 Shift_Up_CM=Float64[], Shift_Dn_CM=Float64[], Shift_Up_ID=Float64[], Shift_Dn_ID=Float64[], 
    #                 Shift_Up_CM_CTS=Float64[], Shift_Dn_CM_CTS=Float64[], Shift_Up_CM_RES=Float64[], Shift_Dn_CM_RES=Float64[], Shift_Up_CM_IND=Float64[], Shift_Dn_CM_IND=Float64[],
    #                 Shift_Up_ID_CTS=Float64[], Shift_Dn_ID_CTS=Float64[], Shift_Up_ID_RES=Float64[], Shift_Dn_ID_RES=Float64[], Shift_Up_ID_IND=Float64[], Shift_Dn_ID_IND=Float64[], 
    #                 New_CM_Load=Float64[], New_Load=Float64[], Original_Load=Float64[], 
    #                 Hourly_Cashflow_Sum=Float64[], Hourly_Cashflow_CM=Float64[], Hourly_Cashflow_ID=Float64[], 
    #                 DA_price=Float64[], ID_price=Float64[], CM_price=Float64[])

    #         scen = 1
    #         for h in hours
    #             for j in nodes.id
    #                 time = h
    #                 node = j
    #                 Up = ShiftUp[scen, h, j]
    #                 Dn = ShiftDn[scen, h, j]
    #                 Up_CM = ShiftUpCM[h, j]
    #                 Dn_CM = ShiftDnCM[h, j]
    #                 Up_ID = ShiftUpID[scen, h, j]
    #                 Dn_ID = ShiftDnID[scen, h, j]
    #                 Up_CM_CTS = ShiftUpCMCTS[h, j]
    #                 Dn_CM_CTS = ShiftDnCMCTS[h, j]
    #                 Up_CM_RES = ShiftUpCMRes[h, j]
    #                 Dn_CM_RES = ShiftDnCMRes[h, j]
    #                 Up_CM_IND = ShiftUpCMInd[h, j]
    #                 Dn_CM_IND = ShiftDnCMInd[h, j]
    #                 Up_ID_CTS = ShiftUpIDCTS[scen, h, j]
    #                 Dn_ID_CTS = ShiftDnIDCTS[scen, h, j]
    #                 Up_ID_RES = ShiftUpIDRes[scen, h, j]
    #                 Dn_ID_RES = ShiftDnIDRes[scen, h, j]
    #                 Up_ID_IND = ShiftUpIDInd[scen, h, j]
    #                 Dn_ID_IND = ShiftDnIDInd[scen, h, j]
    #                 CM_Load = NewCMLoad[h, j]
    #                 New_Load = ScenarioLoad[scen, h, j]
    #                 Original_Load = nodes.load[j][h]
    #                 Cashflow = av_rd_price_dict[j][h]*(ShiftDnCM[h, j] - ShiftUpCM[h, j]) + ID_scen_price_dict[scen][h]*(ShiftDnID[scen, h, j]-ShiftUpID[scen, h, j])
    #                 Cash_CM = av_rd_price_dict[j][h]*(ShiftDnCM[h, j] - ShiftUpCM[h, j])
    #                 Cash_ID = ID_scen_price_dict[scen][h]*(ShiftDnID[scen, h, j]-ShiftUpID[scen, h, j])
    #                 DA = da_price_dict[h]
    #                 ID = ID_indexprice[h]
    #                 CM = av_rd_price_dict[j][h]
    #                 valarray = ([dayindex time node Up Dn Up_CM Dn_CM Up_ID Dn_ID Up_CM_CTS Dn_CM_CTS Up_CM_RES Dn_CM_RES Up_CM_IND Dn_CM_IND Up_ID_CTS Dn_ID_CTS Up_ID_RES Dn_ID_RES Up_ID_IND Dn_ID_IND CM_Load New_Load Original_Load Cashflow Cash_CM Cash_ID DA ID CM])
    #                 push!(output_shifts_nodal_scen1, valarray)
    #             end
    #         end
    #         CSV.write(joinpath(outputpath, "output_nodal_scen1.csv"), output_shifts_nodal_scen1, append = true)
            
    #         scen = 2
    #         for h in hours
    #             for j in nodes.id
    #                 time = h
    #                 node = j
    #                 Up = ShiftUp[scen, h, j]
    #                 Dn = ShiftDn[scen, h, j]
    #                 Up_CM = ShiftUpCM[h, j]
    #                 Dn_CM = ShiftDnCM[h, j]
    #                 Up_ID = ShiftUpID[scen, h, j]
    #                 Dn_ID = ShiftDnID[scen, h, j]
    #                 Up_CM_CTS = ShiftUpCMCTS[h, j]
    #                 Dn_CM_CTS = ShiftDnCMCTS[h, j]
    #                 Up_CM_RES = ShiftUpCMRes[h, j]
    #                 Dn_CM_RES = ShiftDnCMRes[h, j]
    #                 Up_CM_IND = ShiftUpCMInd[h, j]
    #                 Dn_CM_IND = ShiftDnCMInd[h, j]
    #                 Up_ID_CTS = ShiftUpIDCTS[scen, h, j]
    #                 Dn_ID_CTS = ShiftDnIDCTS[scen, h, j]
    #                 Up_ID_RES = ShiftUpIDRes[scen, h, j]
    #                 Dn_ID_RES = ShiftDnIDRes[scen, h, j]
    #                 Up_ID_IND = ShiftUpIDInd[scen, h, j]
    #                 Dn_ID_IND = ShiftDnIDInd[scen, h, j]
    #                 CM_Load = NewCMLoad[h, j]
    #                 New_Load = ScenarioLoad[scen, h, j]
    #                 Original_Load = nodes.load[j][h]
    #                 Cashflow = av_rd_price_dict[j][h]*(ShiftDnCM[h, j] - ShiftUpCM[h, j]) + ID_scen_price_dict[scen][h]*(ShiftDnID[scen, h, j]-ShiftUpID[scen, h, j])
    #                 Cash_CM = av_rd_price_dict[j][h]*(ShiftDnCM[h, j] - ShiftUpCM[h, j])
    #                 Cash_ID = ID_scen_price_dict[scen][h]*(ShiftDnID[scen, h, j]-ShiftUpID[scen, h, j])
    #                 DA = da_price_dict[h]
    #                 ID = ID_indexprice[h]
    #                 CM = av_rd_price_dict[j][h]
    #                 valarray = ([dayindex time node Up Dn Up_CM Dn_CM Up_ID Dn_ID Up_CM_CTS Dn_CM_CTS Up_CM_RES Dn_CM_RES Up_CM_IND Dn_CM_IND Up_ID_CTS Dn_ID_CTS Up_ID_RES Dn_ID_RES Up_ID_IND Dn_ID_IND CM_Load New_Load Original_Load Cashflow Cash_CM Cash_ID DA ID CM])
    #                 push!(output_shifts_nodal_scen2, valarray)
    #             end
    #         end
    #         CSV.write(joinpath(outputpath, "output_nodal_scen2.csv"), output_shifts_nodal_scen2, append = true)
            
    #         scen = 3
    #         for h in hours
    #             for j in nodes.id
    #                 time = h
    #                 node = j
    #                 Up = ShiftUp[scen, h, j]
    #                 Dn = ShiftDn[scen, h, j]
    #                 Up_CM = ShiftUpCM[h, j]
    #                 Dn_CM = ShiftDnCM[h, j]
    #                 Up_ID = ShiftUpID[scen, h, j]
    #                 Dn_ID = ShiftDnID[scen, h, j]
    #                 Up_CM_CTS = ShiftUpCMCTS[h, j]
    #                 Dn_CM_CTS = ShiftDnCMCTS[h, j]
    #                 Up_CM_RES = ShiftUpCMRes[h, j]
    #                 Dn_CM_RES = ShiftDnCMRes[h, j]
    #                 Up_CM_IND = ShiftUpCMInd[h, j]
    #                 Dn_CM_IND = ShiftDnCMInd[h, j]
    #                 Up_ID_CTS = ShiftUpIDCTS[scen, h, j]
    #                 Dn_ID_CTS = ShiftDnIDCTS[scen, h, j]
    #                 Up_ID_RES = ShiftUpIDRes[scen, h, j]
    #                 Dn_ID_RES = ShiftDnIDRes[scen, h, j]
    #                 Up_ID_IND = ShiftUpIDInd[scen, h, j]
    #                 Dn_ID_IND = ShiftDnIDInd[scen, h, j]
    #                 CM_Load = NewCMLoad[h, j]
    #                 New_Load = ScenarioLoad[scen, h, j]
    #                 Original_Load = nodes.load[j][h]
    #                 Cashflow = av_rd_price_dict[j][h]*(ShiftDnCM[h, j] - ShiftUpCM[h, j]) + ID_scen_price_dict[scen][h]*(ShiftDnID[scen, h, j]-ShiftUpID[scen, h, j])
    #                 Cash_CM = av_rd_price_dict[j][h]*(ShiftDnCM[h, j] - ShiftUpCM[h, j])
    #                 Cash_ID = ID_scen_price_dict[scen][h]*(ShiftDnID[scen, h, j]-ShiftUpID[scen, h, j])
    #                 DA = da_price_dict[h]
    #                 ID = ID_indexprice[h]
    #                 CM = av_rd_price_dict[j][h]
    #                 valarray = ([dayindex time node Up Dn Up_CM Dn_CM Up_ID Dn_ID Up_CM_CTS Dn_CM_CTS Up_CM_RES Dn_CM_RES Up_CM_IND Dn_CM_IND Up_ID_CTS Dn_ID_CTS Up_ID_RES Dn_ID_RES Up_ID_IND Dn_ID_IND CM_Load New_Load Original_Load Cashflow Cash_CM Cash_ID DA ID CM])
    #                 push!(output_shifts_nodal_scen3, valarray)
    #             end
    #         end
    #         CSV.write(joinpath(outputpath, "output_nodal_scen3.csv"), output_shifts_nodal_scen3, append = true)
            
    #         scen = 4
    #         for h in hours
    #             for j in nodes.id
    #                 time = h
    #                 node = j
    #                 Up = ShiftUp[scen, h, j]
    #                 Dn = ShiftDn[scen, h, j]
    #                 Up_CM = ShiftUpCM[h, j]
    #                 Dn_CM = ShiftDnCM[h, j]
    #                 Up_ID = ShiftUpID[scen, h, j]
    #                 Dn_ID = ShiftDnID[scen, h, j]
    #                 Up_CM_CTS = ShiftUpCMCTS[h, j]
    #                 Dn_CM_CTS = ShiftDnCMCTS[h, j]
    #                 Up_CM_RES = ShiftUpCMRes[h, j]
    #                 Dn_CM_RES = ShiftDnCMRes[h, j]
    #                 Up_CM_IND = ShiftUpCMInd[h, j]
    #                 Dn_CM_IND = ShiftDnCMInd[h, j]
    #                 Up_ID_CTS = ShiftUpIDCTS[scen, h, j]
    #                 Dn_ID_CTS = ShiftDnIDCTS[scen, h, j]
    #                 Up_ID_RES = ShiftUpIDRes[scen, h, j]
    #                 Dn_ID_RES = ShiftDnIDRes[scen, h, j]
    #                 Up_ID_IND = ShiftUpIDInd[scen, h, j]
    #                 Dn_ID_IND = ShiftDnIDInd[scen, h, j]
    #                 CM_Load = NewCMLoad[h, j]
    #                 New_Load = ScenarioLoad[scen, h, j]
    #                 Original_Load = nodes.load[j][h]
    #                 Cashflow = av_rd_price_dict[j][h]*(ShiftDnCM[h, j] - ShiftUpCM[h, j]) + ID_scen_price_dict[scen][h]*(ShiftDnID[scen, h, j]-ShiftUpID[scen, h, j])
    #                 Cash_CM = av_rd_price_dict[j][h]*(ShiftDnCM[h, j] - ShiftUpCM[h, j])
    #                 Cash_ID = ID_scen_price_dict[scen][h]*(ShiftDnID[scen, h, j]-ShiftUpID[scen, h, j])
    #                 DA = da_price_dict[h]
    #                 ID = ID_indexprice[h]
    #                 CM = av_rd_price_dict[j][h]
    #                 valarray = ([dayindex time node Up Dn Up_CM Dn_CM Up_ID Dn_ID Up_CM_CTS Dn_CM_CTS Up_CM_RES Dn_CM_RES Up_CM_IND Dn_CM_IND Up_ID_CTS Dn_ID_CTS Up_ID_RES Dn_ID_RES Up_ID_IND Dn_ID_IND CM_Load New_Load Original_Load Cashflow Cash_CM Cash_ID DA ID CM])
    #                 push!(output_shifts_nodal_scen4, valarray)
    #             end
    #         end
    #         CSV.write(joinpath(outputpath, "output_nodal_scen4.csv"), output_shifts_nodal_scen4, append = true)

##### TESTING END
### LOOPING OVER YEAR

prog = Progress(length(dayslicer(timeperiod)))
for hours in dayslicer(timeperiod)

    dayindex = Int(hours[end]/24)
    println("Optimzing for day " * string(dayindex) * " and hours " * string(hours) * "...")

    av_rd_price_dict = Dict((n => Dict()) for n in N)
    for n in N
        for t in hours
            if nod_vol_dict[n][t] == 0
                av_rd_price_dict[n][t] = 0
            else
                av_rd_price_dict[n][t] = nod_cost_dict[n][t]/nod_vol_dict[n][t]
            end
        end
    end

    ID_scen_price_dict = Dict(i => Dict() for i in scenarios)
    for h in hours 
        ID_scen_price_dict[1][h] = ID_indexprice[h]
        ID_scen_price_dict[2][h] = ID_highprice[h]
        ID_scen_price_dict[3][h] = ID_lowprice[h]
        ID_scen_price_dict[4][h] = ID_indexprice[h]
    end

    DSO_ID_mod, ShiftUp, ShiftDn, ShiftUpCM, ShiftDnCM, ShiftUpID, ShiftDnID, ShiftUpCMRes, ShiftUpCMCTS, ShiftUpCMInd, 
        ShiftDnCMRes, ShiftDnCMCTS, ShiftDnCMInd, ShiftUpIDCTS, ShiftDnIDCTS, ShiftUpIDRes, ShiftDnIDRes,
        ShiftUpIDInd, ShiftDnIDInd, NewCMLoad, ScenarioLoad = DSO_CM_ID_LoadShift(
        hours, nodes, ID_scen_price_dict, av_rd_price_dict, share_cts, share_res, share_ind, 
        shiftpot_cts, shiftpot_res, shiftpot_ind, isworkhour, scenarios, scen_chance_dict)


        output_DSO_ID_mod_info = DataFrame(timeperiod=String[], termination_status=String[], primal_status=String[], dual_status=String[], objective_value=Float64[], solve_time=Float64[])
        push!(output_DSO_ID_mod_info, [string(hours) string(termination_status(DSO_ID_mod)) string(primal_status(DSO_ID_mod)) string(dual_status(DSO_ID_mod)) objective_value(DSO_ID_mod) solve_time(DSO_ID_mod)])
        CSV.write(joinpath(outputpath, "DSO_ID_mod_info.csv"), output_DSO_ID_mod_info, append=true)
        
        output_shifts_nodal_scen1 = DataFrame(day=Int64[], time=Int64[], node=Int64[], Shift_Up=Float64[], Shift_Dn=Float64[],
                Shift_Up_CM=Float64[], Shift_Dn_CM=Float64[], Shift_Up_ID=Float64[], Shift_Dn_ID=Float64[], 
                Shift_Up_CM_CTS=Float64[], Shift_Dn_CM_CTS=Float64[], Shift_Up_CM_RES=Float64[], Shift_Dn_CM_RES=Float64[], Shift_Up_CM_IND=Float64[], Shift_Dn_CM_IND=Float64[],
                Shift_Up_ID_CTS=Float64[], Shift_Dn_ID_CTS=Float64[], Shift_Up_ID_RES=Float64[], Shift_Dn_ID_RES=Float64[], Shift_Up_ID_IND=Float64[], Shift_Dn_ID_IND=Float64[], 
                New_CM_Load=Float64[], New_Load=Float64[], Original_Load=Float64[], 
                Hourly_Cashflow_Sum=Float64[], Hourly_Cashflow_CM=Float64[], Hourly_Cashflow_ID=Float64[], 
                DA_price=Float64[], ID_price=Float64[], CM_price=Float64[])
        output_shifts_nodal_scen2 = DataFrame(day=Int64[], time=Int64[], node=Int64[], Shift_Up=Float64[], Shift_Dn=Float64[], 
                Shift_Up_CM=Float64[], Shift_Dn_CM=Float64[], Shift_Up_ID=Float64[], Shift_Dn_ID=Float64[], 
                Shift_Up_CM_CTS=Float64[], Shift_Dn_CM_CTS=Float64[], Shift_Up_CM_RES=Float64[], Shift_Dn_CM_RES=Float64[], Shift_Up_CM_IND=Float64[], Shift_Dn_CM_IND=Float64[],
                Shift_Up_ID_CTS=Float64[], Shift_Dn_ID_CTS=Float64[], Shift_Up_ID_RES=Float64[], Shift_Dn_ID_RES=Float64[], Shift_Up_ID_IND=Float64[], Shift_Dn_ID_IND=Float64[], 
                New_CM_Load=Float64[], New_Load=Float64[], Original_Load=Float64[], 
                Hourly_Cashflow_Sum=Float64[], Hourly_Cashflow_CM=Float64[], Hourly_Cashflow_ID=Float64[], 
                DA_price=Float64[], ID_price=Float64[], CM_price=Float64[])
        output_shifts_nodal_scen3 = DataFrame(day=Int64[], time=Int64[], node=Int64[],  Shift_Up=Float64[], Shift_Dn=Float64[],
                Shift_Up_CM=Float64[], Shift_Dn_CM=Float64[], Shift_Up_ID=Float64[], Shift_Dn_ID=Float64[], 
                Shift_Up_CM_CTS=Float64[], Shift_Dn_CM_CTS=Float64[], Shift_Up_CM_RES=Float64[], Shift_Dn_CM_RES=Float64[], Shift_Up_CM_IND=Float64[], Shift_Dn_CM_IND=Float64[],
                Shift_Up_ID_CTS=Float64[], Shift_Dn_ID_CTS=Float64[], Shift_Up_ID_RES=Float64[], Shift_Dn_ID_RES=Float64[], Shift_Up_ID_IND=Float64[], Shift_Dn_ID_IND=Float64[], 
                New_CM_Load=Float64[], New_Load=Float64[], Original_Load=Float64[], 
                Hourly_Cashflow_Sum=Float64[], Hourly_Cashflow_CM=Float64[], Hourly_Cashflow_ID=Float64[], 
                DA_price=Float64[], ID_price=Float64[], CM_price=Float64[])
        output_shifts_nodal_scen4 = DataFrame(day=Int64[], time=Int64[], node=Int64[],  Shift_Up=Float64[], Shift_Dn=Float64[],
                Shift_Up_CM=Float64[], Shift_Dn_CM=Float64[], Shift_Up_ID=Float64[], Shift_Dn_ID=Float64[], 
                Shift_Up_CM_CTS=Float64[], Shift_Dn_CM_CTS=Float64[], Shift_Up_CM_RES=Float64[], Shift_Dn_CM_RES=Float64[], Shift_Up_CM_IND=Float64[], Shift_Dn_CM_IND=Float64[],
                Shift_Up_ID_CTS=Float64[], Shift_Dn_ID_CTS=Float64[], Shift_Up_ID_RES=Float64[], Shift_Dn_ID_RES=Float64[], Shift_Up_ID_IND=Float64[], Shift_Dn_ID_IND=Float64[], 
                New_CM_Load=Float64[], New_Load=Float64[], Original_Load=Float64[], 
                Hourly_Cashflow_Sum=Float64[], Hourly_Cashflow_CM=Float64[], Hourly_Cashflow_ID=Float64[], 
                DA_price=Float64[], ID_price=Float64[], CM_price=Float64[])

    scen = 1
    for h in hours
        for j in nodes.id
            time = h
            node = j
            Up = ShiftUp[scen, h, j]
            Dn = ShiftDn[scen, h, j]
            Up_CM = ShiftUpCM[h, j]
            Dn_CM = ShiftDnCM[h, j]
            Up_ID = ShiftUpID[scen, h, j]
            Dn_ID = ShiftDnID[scen, h, j]
            Up_CM_CTS = ShiftUpCMCTS[h, j]
            Dn_CM_CTS = ShiftDnCMCTS[h, j]
            Up_CM_RES = ShiftUpCMRes[h, j]
            Dn_CM_RES = ShiftDnCMRes[h, j]
            Up_CM_IND = ShiftUpCMInd[h, j]
            Dn_CM_IND = ShiftDnCMInd[h, j]
            Up_ID_CTS = ShiftUpIDCTS[scen, h, j]
            Dn_ID_CTS = ShiftDnIDCTS[scen, h, j]
            Up_ID_RES = ShiftUpIDRes[scen, h, j]
            Dn_ID_RES = ShiftDnIDRes[scen, h, j]
            Up_ID_IND = ShiftUpIDInd[scen, h, j]
            Dn_ID_IND = ShiftDnIDInd[scen, h, j]
            CM_Load = NewCMLoad[h, j]
            New_Load = ScenarioLoad[scen, h, j]
            Original_Load = nodes.load[j][h]
            Cashflow = av_rd_price_dict[j][h]*(ShiftDnCM[h, j] - ShiftUpCM[h, j]) + ID_scen_price_dict[scen][h]*(ShiftDnID[scen, h, j]-ShiftUpID[scen, h, j])
            Cash_CM = av_rd_price_dict[j][h]*(ShiftDnCM[h, j] - ShiftUpCM[h, j])
            Cash_ID = ID_scen_price_dict[scen][h]*(ShiftDnID[scen, h, j]-ShiftUpID[scen, h, j])
            DA = da_price_dict[h]
            ID = ID_indexprice[h]
            CM = av_rd_price_dict[j][h]
            valarray = ([dayindex time node Up Dn Up_CM Dn_CM Up_ID Dn_ID Up_CM_CTS Dn_CM_CTS Up_CM_RES Dn_CM_RES Up_CM_IND Dn_CM_IND Up_ID_CTS Dn_ID_CTS Up_ID_RES Dn_ID_RES Up_ID_IND Dn_ID_IND CM_Load New_Load Original_Load Cashflow Cash_CM Cash_ID DA ID CM])
            push!(output_shifts_nodal_scen1, valarray)
        end
    end
    CSV.write(joinpath(outputpath, "output_nodal_scen1.csv"), output_shifts_nodal_scen1, append = true)
    
    scen = 2
    for h in hours
        for j in nodes.id
            time = h
            node = j
            Up = ShiftUp[scen, h, j]
            Dn = ShiftDn[scen, h, j]
            Up_CM = ShiftUpCM[h, j]
            Dn_CM = ShiftDnCM[h, j]
            Up_ID = ShiftUpID[scen, h, j]
            Dn_ID = ShiftDnID[scen, h, j]
            Up_CM_CTS = ShiftUpCMCTS[h, j]
            Dn_CM_CTS = ShiftDnCMCTS[h, j]
            Up_CM_RES = ShiftUpCMRes[h, j]
            Dn_CM_RES = ShiftDnCMRes[h, j]
            Up_CM_IND = ShiftUpCMInd[h, j]
            Dn_CM_IND = ShiftDnCMInd[h, j]
            Up_ID_CTS = ShiftUpIDCTS[scen, h, j]
            Dn_ID_CTS = ShiftDnIDCTS[scen, h, j]
            Up_ID_RES = ShiftUpIDRes[scen, h, j]
            Dn_ID_RES = ShiftDnIDRes[scen, h, j]
            Up_ID_IND = ShiftUpIDInd[scen, h, j]
            Dn_ID_IND = ShiftDnIDInd[scen, h, j]
            CM_Load = NewCMLoad[h, j]
            New_Load = ScenarioLoad[scen, h, j]
            Original_Load = nodes.load[j][h]
            Cashflow = av_rd_price_dict[j][h]*(ShiftDnCM[h, j] - ShiftUpCM[h, j]) + ID_scen_price_dict[scen][h]*(ShiftDnID[scen, h, j]-ShiftUpID[scen, h, j])
            Cash_CM = av_rd_price_dict[j][h]*(ShiftDnCM[h, j] - ShiftUpCM[h, j])
            Cash_ID = ID_scen_price_dict[scen][h]*(ShiftDnID[scen, h, j]-ShiftUpID[scen, h, j])
            DA = da_price_dict[h]
            ID = ID_indexprice[h]
            CM = av_rd_price_dict[j][h]
            valarray = ([dayindex time node Up Dn Up_CM Dn_CM Up_ID Dn_ID Up_CM_CTS Dn_CM_CTS Up_CM_RES Dn_CM_RES Up_CM_IND Dn_CM_IND Up_ID_CTS Dn_ID_CTS Up_ID_RES Dn_ID_RES Up_ID_IND Dn_ID_IND CM_Load New_Load Original_Load Cashflow Cash_CM Cash_ID DA ID CM])
            push!(output_shifts_nodal_scen2, valarray)
        end
    end
    CSV.write(joinpath(outputpath, "output_nodal_scen2.csv"), output_shifts_nodal_scen2, append = true)
    
    scen = 3
    for h in hours
        for j in nodes.id
            time = h
            node = j
            Up = ShiftUp[scen, h, j]
            Dn = ShiftDn[scen, h, j]
            Up_CM = ShiftUpCM[h, j]
            Dn_CM = ShiftDnCM[h, j]
            Up_ID = ShiftUpID[scen, h, j]
            Dn_ID = ShiftDnID[scen, h, j]
            Up_CM_CTS = ShiftUpCMCTS[h, j]
            Dn_CM_CTS = ShiftDnCMCTS[h, j]
            Up_CM_RES = ShiftUpCMRes[h, j]
            Dn_CM_RES = ShiftDnCMRes[h, j]
            Up_CM_IND = ShiftUpCMInd[h, j]
            Dn_CM_IND = ShiftDnCMInd[h, j]
            Up_ID_CTS = ShiftUpIDCTS[scen, h, j]
            Dn_ID_CTS = ShiftDnIDCTS[scen, h, j]
            Up_ID_RES = ShiftUpIDRes[scen, h, j]
            Dn_ID_RES = ShiftDnIDRes[scen, h, j]
            Up_ID_IND = ShiftUpIDInd[scen, h, j]
            Dn_ID_IND = ShiftDnIDInd[scen, h, j]
            CM_Load = NewCMLoad[h, j]
            New_Load = ScenarioLoad[scen, h, j]
            Original_Load = nodes.load[j][h]
            Cashflow = av_rd_price_dict[j][h]*(ShiftDnCM[h, j] - ShiftUpCM[h, j]) + ID_scen_price_dict[scen][h]*(ShiftDnID[scen, h, j]-ShiftUpID[scen, h, j])
            Cash_CM = av_rd_price_dict[j][h]*(ShiftDnCM[h, j] - ShiftUpCM[h, j])
            Cash_ID = ID_scen_price_dict[scen][h]*(ShiftDnID[scen, h, j]-ShiftUpID[scen, h, j])
            DA = da_price_dict[h]
            ID = ID_indexprice[h]
            CM = av_rd_price_dict[j][h]
            valarray = ([dayindex time node Up Dn Up_CM Dn_CM Up_ID Dn_ID Up_CM_CTS Dn_CM_CTS Up_CM_RES Dn_CM_RES Up_CM_IND Dn_CM_IND Up_ID_CTS Dn_ID_CTS Up_ID_RES Dn_ID_RES Up_ID_IND Dn_ID_IND CM_Load New_Load Original_Load Cashflow Cash_CM Cash_ID DA ID CM])
            push!(output_shifts_nodal_scen3, valarray)
        end
    end
    CSV.write(joinpath(outputpath, "output_nodal_scen3.csv"), output_shifts_nodal_scen3, append = true)
    
    scen = 4
    for h in hours
        for j in nodes.id
            time = h
            node = j
            Up = ShiftUp[scen, h, j]
            Dn = ShiftDn[scen, h, j]
            Up_CM = ShiftUpCM[h, j]
            Dn_CM = ShiftDnCM[h, j]
            Up_ID = ShiftUpID[scen, h, j]
            Dn_ID = ShiftDnID[scen, h, j]
            Up_CM_CTS = ShiftUpCMCTS[h, j]
            Dn_CM_CTS = ShiftDnCMCTS[h, j]
            Up_CM_RES = ShiftUpCMRes[h, j]
            Dn_CM_RES = ShiftDnCMRes[h, j]
            Up_CM_IND = ShiftUpCMInd[h, j]
            Dn_CM_IND = ShiftDnCMInd[h, j]
            Up_ID_CTS = ShiftUpIDCTS[scen, h, j]
            Dn_ID_CTS = ShiftDnIDCTS[scen, h, j]
            Up_ID_RES = ShiftUpIDRes[scen, h, j]
            Dn_ID_RES = ShiftDnIDRes[scen, h, j]
            Up_ID_IND = ShiftUpIDInd[scen, h, j]
            Dn_ID_IND = ShiftDnIDInd[scen, h, j]
            CM_Load = NewCMLoad[h, j]
            New_Load = ScenarioLoad[scen, h, j]
            Original_Load = nodes.load[j][h]
            Cashflow = av_rd_price_dict[j][h]*(ShiftDnCM[h, j] - ShiftUpCM[h, j]) + ID_scen_price_dict[scen][h]*(ShiftDnID[scen, h, j]-ShiftUpID[scen, h, j])
            Cash_CM = av_rd_price_dict[j][h]*(ShiftDnCM[h, j] - ShiftUpCM[h, j])
            Cash_ID = ID_scen_price_dict[scen][h]*(ShiftDnID[scen, h, j]-ShiftUpID[scen, h, j])
            DA = da_price_dict[h]
            ID = ID_indexprice[h]
            CM = av_rd_price_dict[j][h]
            valarray = ([dayindex time node Up Dn Up_CM Dn_CM Up_ID Dn_ID Up_CM_CTS Dn_CM_CTS Up_CM_RES Dn_CM_RES Up_CM_IND Dn_CM_IND Up_ID_CTS Dn_ID_CTS Up_ID_RES Dn_ID_RES Up_ID_IND Dn_ID_IND CM_Load New_Load Original_Load Cashflow Cash_CM Cash_ID DA ID CM])
            push!(output_shifts_nodal_scen4, valarray)
        end
    end
    CSV.write(joinpath(outputpath, "output_nodal_scen4.csv"), output_shifts_nodal_scen4, append = true)
    next!(prog)
end
