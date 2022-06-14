# Multi-market bidding for DSO side flexibility providers: Value from Re-dispatch and Intraday Market participation

Wellnitz, Sonja; Pearson, Simon; Crespo del Granado, Pedro; Hashemipour, Naser

We provide our model code based on JuliaLang (v1.5.4) under the MIT licence.

This code for this model is an enhanced derivative of the code we published for our paper "The value of TSO-DSO coordination in re-dispatch with flexible Decentralized Energy Sources: Insights for Germany in 2030". The code for our previous calculations was on the source code published unter the MIT licence by Xiong et al. (2020) for their paper "Spatial flexibility in redispatch: Supporting low carbon energy systems with Power-to-Gas".

While we have taken care to remove any source code that was not written by us and is not necessary for the execution of our model,
unnecessary fragments may remain. All code used from other authors was published under the MIT License.

# Abstract
As the share of renewable electricity generation increases in most power systems, their intermittent nature will lead to an increased demand for flexible technologies
to balance fluctuations in power supply. Furthermore, the spatial distribution of the different sources of renewable energy will cause increased congestion of the affected
transmission lines. DSO-side flexibility may prove beneficial regarding both of those challenges. However, to this day, this flexibility resource remains largely unused.
Besides missing integration frameworks, the remuneration for the DSO side flexibility providers is not high enough to incentivize investment in this flexibility resource.
We investigate how using the DSO side flexibility not only for the re-dispatch but also for the intraday market improves the financial incentives to provide this flex-
ibility service to the system. In order to do so, we set up a two-stage stochastic techno-economic optimization model adopting the principle of coordinated bidding.
Regarding the flexibility integration into the re-dispatch, we use a decentralized TSO-DSO coordination framework. We find that allowing access to more than one mar-
ket results in a significantly higher value of the DSO side flexibility than when used solely for CM purposes. Furthermore, it allows more DSO side flexibility providers
to effectively offer their service. Consequently, this improves the integration of this potentially crucial future flexibility resource.

# Links

- Xiong et al. (2020): "Spatial flexibility in redispatch: Supporting low carbon energy systems with Power-to-Gas" (https://doi.org/10.1016/j.apenergy.2020.116201).
- They based the technology class definitions on [Joulia.jl](https://github.com/JuliaEnergy/Joulia.jl/) by J. Weibezahn and M. Kendziorski.
- Like Xiong et al., we use the open source electricity system data set [ELMOD](https://ideas.repec.org/p/diw/diwddc/dd83.html) for Germany (2015).

