clear variables; close all; clc;

dataFolder = 'G:\My Drive\Publications\SSCS Magazine\Fall 2025\data\';
survey = 'PA-Survey-v10.xlsx';
dataPath = cat(2,dataFolder,survey);

cmos_data = readtable(dataPath, 'Sheet', 'CMOS');