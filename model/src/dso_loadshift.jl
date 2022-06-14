
function DSO_min_LoadShift(hours,
	nodes::Nodes,
	av_el_price,
	av_rd_price_dict,
	x_ag,
	x_re,
	x_ind,
	s_ag,
	s_re,
	s_ind,
	isworkhour
	)

# create subset of nodes
T = hours    
J = nodes.id
Sbase = nodes.bmva

# calculate average nodal load
loadmean = Dict(i => sum(nodes.load[i][hours])/(length(hours)) for i in keys(nodes.load))

DSO_mod = JuMP.Model(with_optimizer(Gurobi.Optimizer))

	### VARIABLE DECLARATION
		### Variables for sectoral shift
            @variable(DSO_mod, ΔD_up_ag[T, J] >= 0);
            @variable(DSO_mod, ΔD_dn_ag[T, J] >= 0);
            @variable(DSO_mod, ΔD_up_re[T, J] >= 0);
            @variable(DSO_mod, ΔD_dn_re[T, J] >= 0);
            @variable(DSO_mod, ΔD_up_ind[T, J] >= 0);
            @variable(DSO_mod, ΔD_dn_ind[T, J] >= 0);
		### Variables for total shift
			@variable(DSO_mod, ΔD_up[T, J] >= 0);
			@variable(DSO_mod, ΔD_dn[T, J] >= 0);
		### Variable for new Loadprofile
			@variable(DSO_mod, Load[T, J] >= 0);

	### CONSTRAINT DECLARATION		
		### Constraints for total shift
			@constraint(DSO_mod, ShiftUpTotal[j = J, t = T], ΔD_up[t, j] == ΔD_up_ag[t, j] + ΔD_up_re[t, j] + ΔD_up_ind[t, j]);
			@constraint(DSO_mod, ShiftDnTotal[j = J, t = T], ΔD_dn[t, j] == ΔD_dn_ag[t, j] + ΔD_dn_re[t, j] + ΔD_dn_ind[t, j]);
		### Constraints for agricultural, residential shift
			@constraint(DSO_mod, ShiftAgUpMax[j = J, t = T], ΔD_up_ag[t, j] <= x_ag*s_ag*loadmean[j]/Sbase);
			@constraint(DSO_mod, ShiftAgDnMax[j = J, t = T], ΔD_dn_ag[t, j] <= x_ag*s_ag*loadmean[j]/Sbase);
			@constraint(DSO_mod, ShiftReUpMax[j = J, t = T], ΔD_up_re[t, j] <= x_re*s_re*loadmean[j]/Sbase);
			@constraint(DSO_mod, ShiftReDnMax[j = J, t = T], ΔD_dn_re[t, j] <= x_re*s_re*loadmean[j]/Sbase);
		### Constraints for industrial shift
			# if mod(hours[24],168) < 120 
			@constraint(DSO_mod, ShiftIndUpMax[j = J, t = T], ΔD_up_ind[t, j] <= isworkhour[mod(t,24)]*x_ind*s_ind*loadmean[j]/Sbase);
			@constraint(DSO_mod, ShiftIndDnMax[j = J, t = T], ΔD_dn_ind[t, j] <= isworkhour[mod(t,24)]*x_ind*s_ind*loadmean[j]/Sbase);
			#	else
			#@constraint(DSO_mod, ShiftIndUpMax[j = J, t = T], ΔD_up_ind[t, j] == 0);
			#@constraint(DSO_mod, ShiftIndDnMax[j = J, t = T], ΔD_dn_ind[t, j] == 0);
			# end
		### Constraints for ShiftBalances
			@constraint(DSO_mod, ShiftBalAg[j = J],
			sum(ΔD_up_ag[t, j] - ΔD_dn_ag[t, j] for t in hours) == 0);
			@constraint(DSO_mod, ShiftBalRe[j = J],
			sum(ΔD_up_re[t, j] - ΔD_dn_re[t, j] for t in hours) == 0);
			@constraint(DSO_mod, ShiftBalInd[j = J],
			sum(ΔD_up_ind[t, j] - ΔD_dn_ind[t, j] for t in hours) == 0);

		### Constraint for new Loadprofile
			@constraint(DSO_mod, ShiftedLoad[j = J, t = T],
			Load[t, j] == nodes.load[j][t]/Sbase + ΔD_up[t, j] - ΔD_dn[t, j]
			);

	### Objective Function
			@objective(DSO_mod, Min,
			sum(sum(av_el_price*Load[t, j]*Sbase + av_rd_price_dict[j][t]*(ΔD_up[t, j]-ΔD_dn[t, j])*Sbase for t in T) for j in J)
				)

		# Initiate optimisation process
		JuMP.optimize!(DSO_mod)


ShiftUp = JuMP.value.(ΔD_up) * Sbase
ShiftDn = JuMP.value.(ΔD_dn) * Sbase
ShiftAgUp = JuMP.value.(ΔD_up_ag) * Sbase
ShiftAgDn = JuMP.value.(ΔD_dn_ag) * Sbase
ShiftReUp = JuMP.value.(ΔD_up_re) * Sbase
ShiftReDn = JuMP.value.(ΔD_dn_re) * Sbase
ShiftIndUp = JuMP.value.(ΔD_up_ind) * Sbase
ShiftIndDn = JuMP.value.(ΔD_dn_ind) * Sbase
Load_shifted_opt = JuMP.value.(Load) * Sbase


return(Load_shifted_opt,
	ShiftUp,
	ShiftDn,
    ShiftAgUp,
    ShiftAgDn,
    ShiftReUp,
    ShiftReDn,
    ShiftIndUp,
    ShiftIndDn,
)
end

function DSO_EXT_min_LoadShift(hours,
	nodes::Nodes,
	marketprice_dict,
	av_rd_price_dict,
	x_ag,
	x_re,
	x_ind,
	s_ag,
	s_re,
	s_ind,
	isworkhour
	)

# create subset of nodes
T = hours    
J = nodes.id
Sbase = nodes.bmva

# calculate average nodal load
loadmean = Dict(i => sum(nodes.load[i][hours])/(length(hours)) for i in keys(nodes.load))

DSO_mod = JuMP.Model(with_optimizer(Gurobi.Optimizer))

	### VARIABLE DECLARATION
		### Variables for sectoral shift
            @variable(DSO_mod, ΔD_up_ag[T, J] >= 0);
            @variable(DSO_mod, ΔD_dn_ag[T, J] >= 0);
            @variable(DSO_mod, ΔD_up_re[T, J] >= 0);
            @variable(DSO_mod, ΔD_dn_re[T, J] >= 0);
            @variable(DSO_mod, ΔD_up_ind[T, J] >= 0);
            @variable(DSO_mod, ΔD_dn_ind[T, J] >= 0);
		### Variables for total shift
			@variable(DSO_mod, ΔD_up[T, J] >= 0);
			@variable(DSO_mod, ΔD_dn[T, J] >= 0);
		### Variable for new Loadprofile
			@variable(DSO_mod, Load[T, J] >= 0);

	### CONSTRAINT DECLARATION		
		### Constraints for total shift
			@constraint(DSO_mod, ShiftUpTotal[j = J, t = T], ΔD_up[t, j] == ΔD_up_ag[t, j] + ΔD_up_re[t, j] + ΔD_up_ind[t, j]);
			@constraint(DSO_mod, ShiftDnTotal[j = J, t = T], ΔD_dn[t, j] == ΔD_dn_ag[t, j] + ΔD_dn_re[t, j] + ΔD_dn_ind[t, j]);
		### Constraints for agricultural, residential shift
			@constraint(DSO_mod, ShiftAgUpMax[j = J, t = T], ΔD_up_ag[t, j] <= x_ag*s_ag*loadmean[j]/Sbase);
			@constraint(DSO_mod, ShiftAgDnMax[j = J, t = T], ΔD_dn_ag[t, j] <= x_ag*s_ag*loadmean[j]/Sbase);
			@constraint(DSO_mod, ShiftReUpMax[j = J, t = T], ΔD_up_re[t, j] <= x_re*s_re*loadmean[j]/Sbase);
			@constraint(DSO_mod, ShiftReDnMax[j = J, t = T], ΔD_dn_re[t, j] <= x_re*s_re*loadmean[j]/Sbase);
		### Constraints for industrial shift
			# if mod(hours[24],168) < 120 
			@constraint(DSO_mod, ShiftIndUpMax[j = J, t = T], ΔD_up_ind[t, j] <= isworkhour[mod(t,24)]*x_ind*s_ind*loadmean[j]/Sbase);
			@constraint(DSO_mod, ShiftIndDnMax[j = J, t = T], ΔD_dn_ind[t, j] <= isworkhour[mod(t,24)]*x_ind*s_ind*loadmean[j]/Sbase);
			#	else
			#@constraint(DSO_mod, ShiftIndUpMax[j = J, t = T], ΔD_up_ind[t, j] == 0);
			#@constraint(DSO_mod, ShiftIndDnMax[j = J, t = T], ΔD_dn_ind[t, j] == 0);
			# end
		### Constraints for ShiftBalances
			@constraint(DSO_mod, ShiftBalAg[j = J],
			sum(ΔD_up_ag[t, j] - ΔD_dn_ag[t, j] for t in hours) == 0);
			@constraint(DSO_mod, ShiftBalRe[j = J],
			sum(ΔD_up_re[t, j] - ΔD_dn_re[t, j] for t in hours) == 0);
			@constraint(DSO_mod, ShiftBalInd[j = J],
			sum(ΔD_up_ind[t, j] - ΔD_dn_ind[t, j] for t in hours) == 0);

		### Constraint for new Loadprofile
			@constraint(DSO_mod, ShiftedLoad[j = J, t = T],
			Load[t, j] == nodes.load[j][t]/Sbase + ΔD_up[t, j] - ΔD_dn[t, j]
			);

	### Objective Function
			@objective(DSO_mod, Min,
			sum(sum(marketprice_dict[t]*Load[t, j]*Sbase + av_rd_price_dict[j][t]*(ΔD_up[t, j]-ΔD_dn[t, j])*Sbase for t in T) for j in J)
				)

		# Initiate optimisation process
		JuMP.optimize!(DSO_mod)


ShiftUp = JuMP.value.(ΔD_up) * Sbase
ShiftDn = JuMP.value.(ΔD_dn) * Sbase
ShiftAgUp = JuMP.value.(ΔD_up_ag) * Sbase
ShiftAgDn = JuMP.value.(ΔD_dn_ag) * Sbase
ShiftReUp = JuMP.value.(ΔD_up_re) * Sbase
ShiftReDn = JuMP.value.(ΔD_dn_re) * Sbase
ShiftIndUp = JuMP.value.(ΔD_up_ind) * Sbase
ShiftIndDn = JuMP.value.(ΔD_dn_ind) * Sbase
Load_shifted_opt = JuMP.value.(Load) * Sbase


return(Load_shifted_opt,
	ShiftUp,
	ShiftDn,
    ShiftAgUp,
    ShiftAgDn,
    ShiftReUp,
    ShiftReDn,
    ShiftIndUp,
    ShiftIndDn,
)
end