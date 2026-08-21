function value = env_num(name, defaultValue)
%ENV_NUM Numeric environment override, so an MCS/BW sweep can be driven from
%   the shell without editing the script.
%
%   Example:
%     PAPR_MCS=5 PAPR_BW=80 matlab -batch "run('pa_wifi_vht.m')"

value = str2double(getenv(name));
if ~isfinite(value)
    value = defaultValue;
end
end
