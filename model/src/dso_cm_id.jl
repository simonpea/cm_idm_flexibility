function DSO_CM_ID_LoadShift(hours,
	nodes::Nodes,
    id_scen_price_dict,  # NEW FROM REGRESSION
	av_rd_price_dict,
	share_cts,
	share_res,
	share_ind,
	shiftpot_cts,
	shiftpot_res,
	shiftpot_ind,
	isworkhour,
    scenarios,
    scen_chance_dict,
	)
 

loadmean = Dict(node_id => sum(nodes.load[node_id][hours])/(length(hours)) for node_id in keys(nodes.load))

dem_max_res = Dict(node_id => Dict(t => nodes.load[node_id][t]*share_res + loadmean[node_id]*share_res*shiftpot_res   for t in hours) for node_id in keys(nodes.load))
dem_min_res = Dict(node_id => Dict(t => nodes.load[node_id][t]*share_res - loadmean[node_id]*share_res*shiftpot_res   for t in hours) for node_id in keys(nodes.load))
dem_max_cts = Dict(node_id => Dict(t => nodes.load[node_id][t]*share_cts + loadmean[node_id]*share_cts*shiftpot_cts   for t in hours) for node_id in keys(nodes.load))
dem_min_cts = Dict(node_id => Dict(t => nodes.load[node_id][t]*share_cts - loadmean[node_id]*share_cts*shiftpot_cts   for t in hours) for node_id in keys(nodes.load))
dem_max_ind = Dict(node_id => Dict(t => nodes.load[node_id][t]*share_ind 
    + loadmean[node_id]*share_ind*shiftpot_ind*(isworkhour[t%24])   for t in hours) for node_id in keys(nodes.load))
dem_min_ind = Dict(node_id => Dict(t => nodes.load[node_id][t]*share_ind 
    - loadmean[node_id]*share_ind*shiftpot_ind*(isworkhour[t%24])   for t in hours) for node_id in keys(nodes.load))

# create subset of nodes
T = hours    
J = nodes.id
S = scenarios

DSO_ID_mod = JuMP.Model(with_optimizer(Gurobi.Optimizer))

	# ### VARIABLE DECLARATION

	# 	### Variables for sectoral CM shift

        @variable(DSO_ID_mod, ΔD_up_cts_cm[T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_dn_cts_cm[T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_up_res_cm[T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_dn_res_cm[T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_up_ind_cm[T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_dn_ind_cm[T, J] >= 0);

        ### Variables for sectoral ID shift

        @variable(DSO_ID_mod, ΔD_up_cts_id[S, T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_dn_cts_id[S, T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_up_res_id[S, T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_dn_res_id[S, T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_up_ind_id[S, T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_dn_ind_id[S, T, J] >= 0);

        ### Variables for total cm and id shift

        @variable(DSO_ID_mod, ΔD_up_cm[T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_dn_cm[T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_up_id[S, T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_dn_id[S, T, J] >= 0);  
        
        ### Variables for total shift

        @variable(DSO_ID_mod, ΔD_up[S, T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_dn[S, T, J] >= 0);

        ### Variable for new load profiles

        @variable(DSO_ID_mod, CM_Load[T, J] >= 0);
        @variable(DSO_ID_mod, Scen_Load[S, T, J] >= 0);

	# ### CONSTRAINT DECLARATION	

        ### Constraints for total shift -- In paper!

        @constraint(DSO_ID_mod, ShiftUpTotal[s = S, t = T, j = J], 
            ΔD_up[s, t, j] == ΔD_up_cm[t, j] + ΔD_up_id[s, t, j]);
        @constraint(DSO_ID_mod, ShiftDnTotal[s = S, t = T, j = J], 
            ΔD_dn[s, t, j] == ΔD_dn_cm[t, j] + ΔD_dn_id[s, t, j]);
            
        ### Constraints for total cm and id shift -- In paper!

        @constraint(DSO_ID_mod, ShiftUpCM[t = T, j = J],
            ΔD_up_cm[t, j] == ΔD_up_cts_cm[t, j] + ΔD_up_res_cm[t, j] + ΔD_up_ind_cm[t, j])
        @constraint(DSO_ID_mod, ShiftDnCM[t = T, j = J],
            ΔD_dn_cm[t, j] == ΔD_dn_cts_cm[t, j] + ΔD_dn_res_cm[t, j] + ΔD_dn_ind_cm[t, j])

        @constraint(DSO_ID_mod, ShiftUpID[s = S, t = T, j = J],
            ΔD_up_id[s, t, j] == ΔD_up_cts_id[s, t, j] + ΔD_up_res_id[s, t, j] + ΔD_up_ind_id[s, t, j])    
        @constraint(DSO_ID_mod, ShiftDnID[s = S, t = T, j = J],
            ΔD_dn_id[s, t, j] == ΔD_dn_cts_id[s, t, j] + ΔD_dn_res_id[s, t, j] + ΔD_dn_ind_id[s, t, j])    


        ### Constraints for 24 hour balancing -- In paper!

        @constraint(DSO_ID_mod, ShiftBalCTS[j = J, s = S],
            sum(ΔD_up_cts_cm[t, j] + ΔD_up_cts_id[s, t, j] - ΔD_dn_cts_cm[t, j] - ΔD_dn_cts_id[s, t, j] for t in hours) == 0);
        @constraint(DSO_ID_mod, ShiftBalRES[j = J, s = S],
            sum(ΔD_up_res_cm[t, j] + ΔD_up_res_id[s, t, j] - ΔD_dn_res_cm[t, j] - ΔD_dn_res_id[s, t, j] for t in hours) == 0);
        @constraint(DSO_ID_mod, ShiftBalIND[j = J, s = S],
            sum(ΔD_up_ind_cm[t, j] + ΔD_up_ind_id[s, t, j] - ΔD_dn_ind_cm[t, j] - ΔD_dn_ind_id[s, t, j] for t in hours) == 0);

        ### Constraint for maximum and minimum load -- In Paper!
            
        @constraint(DSO_ID_mod, MaxDemCTS[s = S, t = T, j = J],
            nodes.load[j][t]*share_cts + ΔD_up_cts_cm[t, j] + ΔD_up_cts_id[s, t, j] <= dem_max_cts[j][t]);
        @constraint(DSO_ID_mod, MaxDemRES[s = S, t = T, j = J],
            nodes.load[j][t]*share_res + ΔD_up_res_cm[t, j] + ΔD_up_res_id[s, t, j] <= dem_max_res[j][t]);
        @constraint(DSO_ID_mod, MaxDemIND[s = S, t = T, j = J],
            nodes.load[j][t]*share_ind + ΔD_up_ind_cm[t, j] + ΔD_up_ind_id[s, t, j] <= dem_max_ind[j][t]);
        @constraint(DSO_ID_mod, MinDemCTS[s = S, t = T, j = J],
            dem_min_cts[j][t] <= nodes.load[j][t]*share_cts - ΔD_dn_cts_cm[t, j] - ΔD_dn_cts_id[s, t, j]);
        @constraint(DSO_ID_mod, MinDemRES[s = S, t = T, j = J],
            dem_min_res[j][t] <= nodes.load[j][t]*share_res - ΔD_dn_res_cm[t, j] - ΔD_dn_res_id[s, t, j]);
        @constraint(DSO_ID_mod, MinDemIND[s = S, t = T, j = J],
            dem_min_ind[j][t] <= nodes.load[j][t]*share_ind - ΔD_dn_ind_cm[t, j] - ΔD_dn_ind_id[s, t, j]);

        ### Constraint for CM-relevant load and new load profile by scenario

        @constraint(DSO_ID_mod, CMLoad[t = T, j = J],
        CM_Load[t, j] == nodes.load[j][t] + ΔD_up_cm[t, j] - ΔD_up_cm[t, j]);

        @constraint(DSO_ID_mod, ScenarioLoad[s = S, t = T, j = J],
        Scen_Load[s, t, j] == nodes.load[j][t] + ΔD_up[s, t, j] - ΔD_dn[s, t, j]);

        ### TODO Constraint for no ID shifting in scenario 4
        @constraint(DSO_ID_mod, NoAcceptUp[s = S[end], t = T, j = J],
        ΔD_up_id[s, t, j] == 0);

        @constraint(DSO_ID_mod, NoAcceptDn[s = S[end], t = T, j = J],
        ΔD_dn_id[s, t, j] == 0);

### Objective Function

        @objective(DSO_ID_mod, Max,
        sum(
            sum(av_rd_price_dict[j][t]*(ΔD_dn_cm[t, j]-ΔD_up_cm[t, j])
                    + sum(scen_chance_dict[s]*id_scen_price_dict[s][t]*(ΔD_dn_id[s, t, j]-ΔD_up_id[s, t, j]) 
                        for s in S)
                for t in T)
            for j in J)
        )
        
    # Initiate optimization process
    JuMP.optimize!(DSO_ID_mod)

    ShiftUp = JuMP.value.(ΔD_up)
    ShiftDn = JuMP.value.(ΔD_dn)    
    ShiftUpCM = JuMP.value.(ΔD_up_cm)
    ShiftDnCM = JuMP.value.(ΔD_dn_cm)
    ShiftUpID = JuMP.value.(ΔD_up_id)
    ShiftDnID = JuMP.value.(ΔD_dn_id)
    ShiftUpCMRes = JuMP.value.(ΔD_up_res_cm)
    ShiftUpCMCTS = JuMP.value.(ΔD_up_cts_cm)
    ShiftUpCMInd = JuMP.value.(ΔD_up_ind_cm)
    ShiftDnCMRes = JuMP.value.(ΔD_dn_res_cm)
    ShiftDnCMCTS = JuMP.value.(ΔD_dn_cts_cm)
    ShiftDnCMInd = JuMP.value.(ΔD_dn_ind_cm)
    ShiftUpIDCTS = JuMP.value.(ΔD_up_cts_id)
    ShiftDnIDCTS = JuMP.value.(ΔD_dn_cts_id)
    ShiftUpIDRes = JuMP.value.(ΔD_up_res_id)
    ShiftDnIDRes = JuMP.value.(ΔD_dn_res_id)
    ShiftUpIDInd = JuMP.value.(ΔD_up_ind_id)
    ShiftDnIDInd = JuMP.value.(ΔD_dn_ind_id)

    NewCMLoad = JuMP.value.(CM_Load)
    ScenarioLoads = JuMP.value.(Scen_Load)

# TODO check
    return(
        DSO_ID_mod,
        ShiftUp,
        ShiftDn,
        ShiftUpCM,
        ShiftDnCM,
        ShiftUpID,
        ShiftDnID,
        ShiftUpCMRes,
        ShiftUpCMCTS,
        ShiftUpCMInd,
        ShiftDnCMRes,
        ShiftDnCMCTS,
        ShiftDnCMInd,
        ShiftUpIDCTS,
        ShiftDnIDCTS,
        ShiftUpIDRes,
        ShiftDnIDRes,
        ShiftUpIDInd,
        ShiftDnIDInd,
        NewCMLoad,
        ScenarioLoads
)
end

function DSO_CM_ID_LoadShift_NoRisk(hours,
	nodes::Nodes,
    id_scen_price_dict,  # NEW FROM REGRESSION
	av_rd_price_dict,
	share_cts,
	share_res,
	share_ind,
	shiftpot_cts,
	shiftpot_res,
	shiftpot_ind,
	isworkhour,
    scenarios,
    scen_chance_dict,
	)
 

loadmean = Dict(node_id => sum(nodes.load[node_id][hours])/(length(hours)) for node_id in keys(nodes.load))

dem_max_res = Dict(node_id => Dict(t => nodes.load[node_id][t]*share_res + loadmean[node_id]*share_res*shiftpot_res   for t in hours) for node_id in keys(nodes.load))
dem_min_res = Dict(node_id => Dict(t => nodes.load[node_id][t]*share_res - loadmean[node_id]*share_res*shiftpot_res   for t in hours) for node_id in keys(nodes.load))
dem_max_cts = Dict(node_id => Dict(t => nodes.load[node_id][t]*share_cts + loadmean[node_id]*share_cts*shiftpot_cts   for t in hours) for node_id in keys(nodes.load))
dem_min_cts = Dict(node_id => Dict(t => nodes.load[node_id][t]*share_cts - loadmean[node_id]*share_cts*shiftpot_cts   for t in hours) for node_id in keys(nodes.load))
dem_max_ind = Dict(node_id => Dict(t => nodes.load[node_id][t]*share_ind 
    + loadmean[node_id]*share_ind*shiftpot_ind*(isworkhour[t%24])   for t in hours) for node_id in keys(nodes.load))
dem_min_ind = Dict(node_id => Dict(t => nodes.load[node_id][t]*share_ind 
    - loadmean[node_id]*share_ind*shiftpot_ind*(isworkhour[t%24])   for t in hours) for node_id in keys(nodes.load))

# create subset of nodes
T = hours    
J = nodes.id
S = scenarios

DSO_ID_mod = JuMP.Model(with_optimizer(Gurobi.Optimizer))

	# ### VARIABLE DECLARATION

	# 	### Variables for sectoral CM shift

        @variable(DSO_ID_mod, ΔD_up_cts_cm[T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_dn_cts_cm[T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_up_res_cm[T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_dn_res_cm[T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_up_ind_cm[T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_dn_ind_cm[T, J] >= 0);

        ### Variables for sectoral ID shift

        @variable(DSO_ID_mod, ΔD_up_cts_id[S, T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_dn_cts_id[S, T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_up_res_id[S, T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_dn_res_id[S, T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_up_ind_id[S, T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_dn_ind_id[S, T, J] >= 0);

        ### Variables for total cm and id shift

        @variable(DSO_ID_mod, ΔD_up_cm[T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_dn_cm[T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_up_id[S, T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_dn_id[S, T, J] >= 0);  
        
        ### Variables for total shift

        @variable(DSO_ID_mod, ΔD_up[S, T, J] >= 0);
        @variable(DSO_ID_mod, ΔD_dn[S, T, J] >= 0);

        ### Variable for new load profiles

        @variable(DSO_ID_mod, CM_Load[T, J] >= 0);
        @variable(DSO_ID_mod, Scen_Load[S, T, J] >= 0);

	# ### CONSTRAINT DECLARATION	

        ### Constraints for total shift -- In paper!

        @constraint(DSO_ID_mod, ShiftUpTotal[s = S, t = T, j = J], 
            ΔD_up[s, t, j] == ΔD_up_cm[t, j] + ΔD_up_id[s, t, j]);
        @constraint(DSO_ID_mod, ShiftDnTotal[s = S, t = T, j = J], 
            ΔD_dn[s, t, j] == ΔD_dn_cm[t, j] + ΔD_dn_id[s, t, j]);
            
        ### Constraints for total cm and id shift -- In paper!

        @constraint(DSO_ID_mod, ShiftUpCM[t = T, j = J],
            ΔD_up_cm[t, j] == ΔD_up_cts_cm[t, j] + ΔD_up_res_cm[t, j] + ΔD_up_ind_cm[t, j])
        @constraint(DSO_ID_mod, ShiftDnCM[t = T, j = J],
            ΔD_dn_cm[t, j] == ΔD_dn_cts_cm[t, j] + ΔD_dn_res_cm[t, j] + ΔD_dn_ind_cm[t, j])

        @constraint(DSO_ID_mod, ShiftUpID[s = S, t = T, j = J],
            ΔD_up_id[s, t, j] == ΔD_up_cts_id[s, t, j] + ΔD_up_res_id[s, t, j] + ΔD_up_ind_id[s, t, j])    
        @constraint(DSO_ID_mod, ShiftDnID[s = S, t = T, j = J],
            ΔD_dn_id[s, t, j] == ΔD_dn_cts_id[s, t, j] + ΔD_dn_res_id[s, t, j] + ΔD_dn_ind_id[s, t, j])    


        ### Constraints for 24 hour balancing -- In paper!

        @constraint(DSO_ID_mod, ShiftBalCTS[j = J, s = S],
            sum(ΔD_up_cts_cm[t, j] + ΔD_up_cts_id[s, t, j] - ΔD_dn_cts_cm[t, j] - ΔD_dn_cts_id[s, t, j] for t in hours) == 0);
        @constraint(DSO_ID_mod, ShiftBalRES[j = J, s = S],
            sum(ΔD_up_res_cm[t, j] + ΔD_up_res_id[s, t, j] - ΔD_dn_res_cm[t, j] - ΔD_dn_res_id[s, t, j] for t in hours) == 0);
        @constraint(DSO_ID_mod, ShiftBalIND[j = J, s = S],
            sum(ΔD_up_ind_cm[t, j] + ΔD_up_ind_id[s, t, j] - ΔD_dn_ind_cm[t, j] - ΔD_dn_ind_id[s, t, j] for t in hours) == 0);

        ### Constraint for maximum and minimum load -- In Paper!
            
        @constraint(DSO_ID_mod, MaxDemCTS[s = S, t = T, j = J],
            nodes.load[j][t]*share_cts + ΔD_up_cts_cm[t, j] + ΔD_up_cts_id[s, t, j] <= dem_max_cts[j][t]);
        @constraint(DSO_ID_mod, MaxDemRES[s = S, t = T, j = J],
            nodes.load[j][t]*share_res + ΔD_up_res_cm[t, j] + ΔD_up_res_id[s, t, j] <= dem_max_res[j][t]);
        @constraint(DSO_ID_mod, MaxDemIND[s = S, t = T, j = J],
            nodes.load[j][t]*share_ind + ΔD_up_ind_cm[t, j] + ΔD_up_ind_id[s, t, j] <= dem_max_ind[j][t]);
        @constraint(DSO_ID_mod, MinDemCTS[s = S, t = T, j = J],
            dem_min_cts[j][t] <= nodes.load[j][t]*share_cts - ΔD_dn_cts_cm[t, j] - ΔD_dn_cts_id[s, t, j]);
        @constraint(DSO_ID_mod, MinDemRES[s = S, t = T, j = J],
            dem_min_res[j][t] <= nodes.load[j][t]*share_res - ΔD_dn_res_cm[t, j] - ΔD_dn_res_id[s, t, j]);
        @constraint(DSO_ID_mod, MinDemIND[s = S, t = T, j = J],
            dem_min_ind[j][t] <= nodes.load[j][t]*share_ind - ΔD_dn_ind_cm[t, j] - ΔD_dn_ind_id[s, t, j]);

        ### Constraint for CM-relevant load and new load profile by scenario

        @constraint(DSO_ID_mod, CMLoad[t = T, j = J],
        CM_Load[t, j] == nodes.load[j][t] + ΔD_up_cm[t, j] - ΔD_up_cm[t, j]);

        @constraint(DSO_ID_mod, ScenarioLoad[s = S, t = T, j = J],
        Scen_Load[s, t, j] == nodes.load[j][t] + ΔD_up[s, t, j] - ΔD_dn[s, t, j]);

        # ### TODO Constraint for no ID shifting in scenario 4
        # @constraint(DSO_ID_mod, NoAcceptUp[s = S[end], t = T, j = J],
        # ΔD_up_id[s, t, j] == 0);

        # @constraint(DSO_ID_mod, NoAcceptDn[s = S[end], t = T, j = J],
        # ΔD_dn_id[s, t, j] == 0);

### Objective Function

        @objective(DSO_ID_mod, Max,
        sum(
            sum(av_rd_price_dict[j][t]*(ΔD_dn_cm[t, j]-ΔD_up_cm[t, j])
                    + sum(scen_chance_dict[s]*id_scen_price_dict[s][t]*(ΔD_dn_id[s, t, j]-ΔD_up_id[s, t, j]) 
                        for s in S)
                for t in T)
            for j in J)
        )
        
    # Initiate optimization process
    JuMP.optimize!(DSO_ID_mod)

    ShiftUp = JuMP.value.(ΔD_up)
    ShiftDn = JuMP.value.(ΔD_dn)    
    ShiftUpCM = JuMP.value.(ΔD_up_cm)
    ShiftDnCM = JuMP.value.(ΔD_dn_cm)
    ShiftUpID = JuMP.value.(ΔD_up_id)
    ShiftDnID = JuMP.value.(ΔD_dn_id)
    ShiftUpCMRes = JuMP.value.(ΔD_up_res_cm)
    ShiftUpCMCTS = JuMP.value.(ΔD_up_cts_cm)
    ShiftUpCMInd = JuMP.value.(ΔD_up_ind_cm)
    ShiftDnCMRes = JuMP.value.(ΔD_dn_res_cm)
    ShiftDnCMCTS = JuMP.value.(ΔD_dn_cts_cm)
    ShiftDnCMInd = JuMP.value.(ΔD_dn_ind_cm)
    ShiftUpIDCTS = JuMP.value.(ΔD_up_cts_id)
    ShiftDnIDCTS = JuMP.value.(ΔD_dn_cts_id)
    ShiftUpIDRes = JuMP.value.(ΔD_up_res_id)
    ShiftDnIDRes = JuMP.value.(ΔD_dn_res_id)
    ShiftUpIDInd = JuMP.value.(ΔD_up_ind_id)
    ShiftDnIDInd = JuMP.value.(ΔD_dn_ind_id)

    NewCMLoad = JuMP.value.(CM_Load)
    ScenarioLoads = JuMP.value.(Scen_Load)

# TODO check
    return(
        DSO_ID_mod,
        ShiftUp,
        ShiftDn,
        ShiftUpCM,
        ShiftDnCM,
        ShiftUpID,
        ShiftDnID,
        ShiftUpCMRes,
        ShiftUpCMCTS,
        ShiftUpCMInd,
        ShiftDnCMRes,
        ShiftDnCMCTS,
        ShiftDnCMInd,
        ShiftUpIDCTS,
        ShiftDnIDCTS,
        ShiftUpIDRes,
        ShiftDnIDRes,
        ShiftUpIDInd,
        ShiftDnIDInd,
        NewCMLoad,
        ScenarioLoads
)
end