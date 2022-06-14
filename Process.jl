using Pkg
Pkg.activate("RunDSO")
using CSV
using DataFrames
using ProgressMeter

writing = false
case = "reference"




### Normal terminal data
if case == "reference"
    scen1_chance = 0.45
    scen2_chance = 0.25
    scen3_chance = 0.2
    scen4_chance = 0.1

    outputpath = "output/original/full/"
    processpath = "processed_output/original/"
end

# Sensitivity terminal data
if case == "sensitivity" 
    scen1_chance = 0.4
    scen2_chance = 0.2
    scen3_chance = 0.15
    scen4_chance = 0.25

    outputpath = "output/sensitivity/full/"
    processpath = "processed_output/sensitivity/"
end

if case == "no_risk" 
    scen1_chance = 0.5
    scen2_chance = 0.25
    scen3_chance = 0.25
    scen4_chance = 0

    outputpath = "output/no_risk/"
    processpath = "processed_output/no_risk/"
end

coordinates_df = CSV.read("NewData/nodeCoordinates.csv", DataFrame)[!, 1:4]

nodes=coordinates_df.node

scen1_df = CSV.read(joinpath(outputpath, "output_nodal_scen1.csv"), DataFrame)
scen2_df = CSV.read(joinpath(outputpath, "output_nodal_scen2.csv"), DataFrame)
scen3_df = CSV.read(joinpath(outputpath, "output_nodal_scen3.csv"), DataFrame)
scen4_df = CSV.read(joinpath(outputpath, "output_nodal_scen4.csv"), DataFrame)

function yearlyKPI(scen1, scen2, scen3, scen4)
    yearly_KPI = DataFrame()
    yearly_KPI.Value = ["ID Price", "Revenue CM (Mio. Euro)", "Revenue ID (Mio. Euro)", "Revenue total (Mio. Euro)", "Volume used for CM (TWh)", "Volume traded on IDM (TWh)", "Volume of Load Shifting (TWh)", "Average Value for CM (Euro per MWh)", "Average Value on ID (Euro per MWh)", "Average Value of Load Shifting (Euro per MWh)"]
    yearly_KPI[!, "Scenario 1"]= ["Index", sum(scen1.Hourly_Cashflow_CM)/1000000, sum(scen1.Hourly_Cashflow_ID)/1000000, sum(scen1.Hourly_Cashflow_Sum)/1000000, sum(scen1.Shift_Dn_CM)/1000000, sum(scen1.Shift_Dn_ID)/1000000,  sum(scen1.Shift_Up)/1000000, sum(scen1.Hourly_Cashflow_CM)/sum(scen1.Shift_Up_CM), sum(scen1.Hourly_Cashflow_ID)/sum(scen1.Shift_Up_ID), sum(scen1.Hourly_Cashflow_Sum)/sum(scen1.Shift_Up)]
    yearly_KPI[!, "Scenario 2"]= ["High", sum(scen2.Hourly_Cashflow_CM)/1000000, sum(scen2.Hourly_Cashflow_ID)/1000000, sum(scen2.Hourly_Cashflow_Sum)/1000000, sum(scen2.Shift_Dn_CM)/1000000, sum(scen2.Shift_Dn_ID)/1000000, sum(scen2.Shift_Up)/1000000, sum(scen2.Hourly_Cashflow_CM)/sum(scen2.Shift_Up_CM), sum(scen2.Hourly_Cashflow_ID)/sum(scen2.Shift_Up_ID), sum(scen2.Hourly_Cashflow_Sum)/sum(scen2.Shift_Up)]
    yearly_KPI[!, "Scenario 3"]= ["Low", sum(scen3.Hourly_Cashflow_CM)/1000000, sum(scen3.Hourly_Cashflow_ID)/1000000, sum(scen3.Hourly_Cashflow_Sum)/1000000, sum(scen3.Shift_Dn_CM)/1000000, sum(scen3.Shift_Dn_ID)/1000000, sum(scen3.Shift_Up)/1000000, sum(scen3.Hourly_Cashflow_CM)/sum(scen3.Shift_Up_CM), sum(scen3.Hourly_Cashflow_ID)/sum(scen3.Shift_Up_ID), sum(scen3.Hourly_Cashflow_Sum)/sum(scen3.Shift_Up)]
    yearly_KPI[!, "Scenario 4"]= ["N/A", sum(scen4.Hourly_Cashflow_CM)/1000000, sum(scen4.Hourly_Cashflow_ID)/1000000, sum(scen4.Hourly_Cashflow_Sum)/1000000, sum(scen4.Shift_Dn_CM)/1000000, sum(scen4.Shift_Dn_ID)/1000000, sum(scen4.Shift_Up)/1000000, sum(scen4.Hourly_Cashflow_CM)/sum(scen4.Shift_Up_CM), 0, sum(scen4.Hourly_Cashflow_Sum)/sum(scen4.Shift_Up)]
    rowdict = Dict()
    for row in 2:nrow(yearly_KPI)-3
    rowdict[row] = scen1_chance * yearly_KPI[row, "Scenario 1"] + scen2_chance * yearly_KPI[row, "Scenario 2"] + scen3_chance * yearly_KPI[row, "Scenario 3"] + scen4_chance * yearly_KPI[row, "Scenario 4"]
    end
    rowdict[nrow(yearly_KPI)-2] = rowdict[2]/rowdict[5]
    rowdict[nrow(yearly_KPI)-1] = rowdict[3]/rowdict[6]
    rowdict[nrow(yearly_KPI)] = rowdict[4]/rowdict[7]
    insertcols!(yearly_KPI, 2, :Expected_Values => ["N/A";[rowdict[row] for row in 2:nrow(yearly_KPI)]])
    #yearly_KPI[!, "Expected Values"] = ["N/A";[rowdict[row] for row in 2:nrow(yearly_KPI)]]
    return yearly_KPI
end

function DailyNodalValues(scenario_df)
    day_node_list=[]
    for day in 1:365
        day_node_list = vcat(day_node_list, repeat([day],length(coordinates_df.node)))
    end
    daily_value_df = DataFrame(day=day_node_list,node=repeat(coordinates_df.node, 365))
    temp = sort(scenario_df, [:day, :node])
    prog = Progress(length(names(temp)[4:end]))
    for col in names(temp)[4:end]
        daily_value_list = [sum(temp[!, col][(i-1)*24+1:i*24]) for i in (1:365*485)]
        daily_value_df[!, col] = daily_value_list
        next!(prog)
    end
    rename!(daily_value_df, [:Hourly_Cashflow_Sum ,:Hourly_Cashflow_CM, :Hourly_Cashflow_ID] .=>  [:Daily_Cashflow_Sum ,:Daily_Cashflow_CM, :Daily_Cashflow_ID])
    return daily_value_df
end

function DailyNodalToGlobalValues(daily_nodal_df)
    temp = copy(daily_nodal_df)
    daily_global_df = DataFrame(day=collect(1:365))
    prog = Progress(length(names(temp)[3:end]))
    for col in names(temp)[3:end]
        daily_value_list = [sum(temp[!, col][(i-1)*485+1:i*485]) for i in (1:365)]
        daily_global_df[!, col] = daily_value_list
        next!(prog)
    end
    return daily_global_df
end

function YearlyNodalSum(daily_nodal_df)
    temp = sort(daily_nodal_df, :node)
    yearly_nodal_df = DataFrame(node=unique(temp.node))
    prog = Progress(length(names(temp)[3:end]))
    for col in names(temp)[3:end]
        yearly_value_list = [sum(temp[!, col][(i-1)*365+1:i*365]) for i in (1:485)]
        yearly_nodal_df[!, col] = yearly_value_list
        next!(prog)
    end
    rename!(yearly_nodal_df, [:Shift_Up ,:Shift_Up_CM, :Shift_Up_ID, :Daily_Cashflow_Sum, :Daily_Cashflow_CM, :Daily_Cashflow_ID] .=>  [:Shift_Total ,:Shift_CM, :Shift_ID, :Revenue_Total, :Revenue_CM, :Revenue_ID])
    yearly_nodal_df = yearly_nodal_df[!, [:node, :Shift_Total ,:Shift_CM, :Shift_ID, :Revenue_Total, :Revenue_CM, :Revenue_ID]]
    return yearly_nodal_df
end

function Expected_df(scen1, scen2, scen3, scen4)
    valcol = findfirst(x -> x == "Shift_Up", names(scen1))
    expected_df = DataFrame()
    for col in names(scen1)[1:valcol-1]
        expected_df[!, col] = scen1[!, col]
    end
    for col in names(scen1)[valcol:end]
        expected_df[!, col] = scen1_chance * scen1[!, col] + scen2_chance * scen2[!, col] + scen3_chance * scen3[!, col] + scen4_chance * scen4[!, col]
    end
    return expected_df
end


daily_nodal_scen1_df = DailyNodalValues(scen1_df)
daily_nodal_scen2_df = DailyNodalValues(scen2_df)
daily_nodal_scen3_df = DailyNodalValues(scen3_df)
daily_nodal_scen4_df = DailyNodalValues(scen4_df)
daily_nodal_expected_df = Expected_df(daily_nodal_scen1_df, daily_nodal_scen2_df, daily_nodal_scen3_df, daily_nodal_scen4_df)

if writing
    CSV.write(joinpath(processpath, "daily_nodal/daily_nodal_scen1.csv"), daily_nodal_scen1_df)
    CSV.write(joinpath(processpath, "daily_nodal/daily_nodal_scen2.csv"), daily_nodal_scen2_df)
    CSV.write(joinpath(processpath, "daily_nodal/daily_nodal_scen3.csv"), daily_nodal_scen3_df)
    CSV.write(joinpath(processpath, "daily_nodal/daily_nodal_scen4.csv"), daily_nodal_scen4_df)
    CSV.write(joinpath(processpath, "daily_nodal/daily_nodal_expected.csv"), daily_nodal_expected_df)
end

daily_global_scen1_df = DailyNodalToGlobalValues(daily_nodal_scen1_df)
daily_global_scen2_df = DailyNodalToGlobalValues(daily_nodal_scen2_df)
daily_global_scen3_df = DailyNodalToGlobalValues(daily_nodal_scen3_df)
daily_global_scen4_df = DailyNodalToGlobalValues(daily_nodal_scen4_df)
daily_global_expected_df = Expected_df(daily_global_scen1_df, daily_global_scen2_df, daily_global_scen3_df, daily_global_scen4_df)

if writing
    CSV.write(joinpath(processpath, "daily_global/daily_global_scen1.csv"), daily_global_scen1_df)
    CSV.write(joinpath(processpath, "daily_global/daily_global_scen2.csv"), daily_global_scen2_df)
    CSV.write(joinpath(processpath, "daily_global/daily_global_scen3.csv"), daily_global_scen3_df)
    CSV.write(joinpath(processpath, "daily_global/daily_global_scen4.csv"), daily_global_scen4_df)
    CSV.write(joinpath(processpath, "daily_global/daily_global_expected.csv"), daily_global_expected_df)
end

yearly_KPI = yearlyKPI(scen1_df,scen2_df,scen3_df,scen4_df)
if writing CSV.write(joinpath(processpath, "yearly_kpi.csv"), yearly_KPI) end
#CSV.write(joinpath(processpath, "yearly_kpi.csv"), yearly_KPI)

yearly_nodal_df_scen1 = YearlyNodalSum(daily_nodal_scen1_df)
yearly_nodal_values_scen1 = hcat(coordinates_df, yearly_nodal_df_scen1[!, 2:end])
yearly_nodal_df_scen2 = YearlyNodalSum(daily_nodal_scen2_df)
yearly_nodal_values_scen2 = hcat(coordinates_df, yearly_nodal_df_scen2[!, 2:end])
yearly_nodal_df_scen3 = YearlyNodalSum(daily_nodal_scen3_df)
yearly_nodal_values_scen3 = hcat(coordinates_df, yearly_nodal_df_scen3[!, 2:end])
yearly_nodal_df_scen4 = YearlyNodalSum(daily_nodal_scen4_df)
yearly_nodal_values_scen4 = hcat(coordinates_df, yearly_nodal_df_scen4[!, 2:end])
yearly_nodal_values_expected = copy(yearly_nodal_values_scen1[!, 1:4])
for col in names(yearly_nodal_values_scen1)[5:end]
    yearly_nodal_values_expected[!, col] = scen1_chance * yearly_nodal_values_scen1[!, col] + scen2_chance * yearly_nodal_values_scen2[!, col] + scen3_chance * yearly_nodal_values_scen3[!, col] + scen4_chance * yearly_nodal_values_scen4[!, col]
end
if writing
    CSV.write(joinpath(processpath, "yearly_nodal_with_coords/yearly_nodal_values_scen1.csv"), yearly_nodal_values_scen1)
    CSV.write(joinpath(processpath, "yearly_nodal_with_coords/yearly_nodal_values_scen2.csv"), yearly_nodal_values_scen2)
    CSV.write(joinpath(processpath, "yearly_nodal_with_coords/yearly_nodal_values_scen3.csv"), yearly_nodal_values_scen3)
    CSV.write(joinpath(processpath, "yearly_nodal_with_coords/yearly_nodal_values_scen4.csv"), yearly_nodal_values_scen4)
    CSV.write(joinpath(processpath, "yearly_nodal_with_coords/yearly_nodal_values_expected.csv"), yearly_nodal_values_expected)
end

findmax(yearly_nodal_values_expected.Revenue_Total)
temp = subset(yearly_nodal_values_expected, :Shift_Total => x -> x .!= 0)
findmin(temp.Revenue_Total)

temp[!, "Average_Rev"] = temp.Revenue_Total ./ temp.Shift_Total
delete!(temp, findmax(temp.Average_Rev)[2])
temp[findmax(temp.Average_Rev)[2], :]
temp[findmin(temp.Average_Rev)[2], :]
bestnode = 12
worstnode = 290

# daily werte: revenue pro verwendungszweck, shifting pro verwendungszweck

daily_nodal_expected_df
daily_bestnode_df = subset(daily_nodal_expected_df, :node => x -> x .== bestnode)
daily_worstnode_df = subset(daily_nodal_expected_df, :node => x -> x .== worstnode)
CSV.write(joinpath(processpath, "daily_bestnode.csv"), daily_bestnode_df)
CSV.write(joinpath(processpath, "daily_worstnode.csv"), daily_worstnode_df)


temp = subset(scen1_df, :node => x -> x .== 5)
temp