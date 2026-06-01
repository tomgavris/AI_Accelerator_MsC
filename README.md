# Systolic Array

 This project details the creation of a Systolic Array (**SA**), which will be used in a Artificial Intelligence (**AI**) accelerator for the purposes of my intersnhip at "Universität Bremen".

## Overview

The purpose of this project is to create a fully functional Systolic Array (**SA**), comprised of MxM Processing Elements (**PE**). In the first part of the development process, a SA was created with simple processing elements, found in the folder **SA_with_PE**, and later the processing elements were modified into Dot Product Processing Elements (DPPE), found in the folder **DPPE_SA**.

## Description

The Systolic Array being built is currently comprised of the following modules, following a bottom to top view of the system:

**DP2:** This module is a fully combinational circuit, meant to hanlde just the MAC operations of the SA. Depending on the application and the designer's preference, this module can handle an OP number of operands at once.

**DPPE:** Within this module an NxN number of DP2 modules is instantiated. Every DP2 module is assigned an OP number of weight registers, to store the weight values. This level also handles boundary reggitisters logic, since partial sum and activations registers are required between two consecutive DPPEs. In order to minimize area and cost boundary DPPEs can lack, depending on their position inside the grid, activations or partial sum registers, or even both. 

**DPPE_SA:** This is the level DPPEs are connected together. 

## Supervisor

Alberto Garcia-Ortiz, Head of Chair for Microelectronics at the University of Bremen 

## Guidance

Sebastian Fischer, Scientific Assistant/Ph.D. Candidate