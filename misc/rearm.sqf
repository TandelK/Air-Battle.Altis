/*
    Vehicle service pad script for Air-Battle.Altis.

    Expected usage from trigger activation:
        _handle = [thisList] execVM "misc\rearm.sqf";

    The script intentionally runs on the server only so multiplayer trigger
    activation does not start duplicate service jobs on every connected client.
*/
if (!isServer) exitWith {};

params [
    ["_targets", [], [[], objNull]]
];

private _targetList = if (_targets isEqualType []) then { _targets } else { [_targets] };
private _vehicles = (_targetList apply { vehicle _x }) select {
    !isNull _x &&
    { alive _x } &&
    { !(_x isKindOf "Man") } &&
    { !(_x isKindOf "ParachuteBase") }
};

if (_vehicles isEqualTo []) exitWith {};

private _vehicle = _vehicles # 0;
if (_vehicle getVariable ["AB_serviceInProgress", false]) exitWith {
    _vehicle vehicleChat "Service is already in progress.";
};

_vehicle setVariable ["AB_serviceInProgress", true, true];

private _vehicleClass = typeOf _vehicle;
private _vehicleConfig = configFile >> "CfgVehicles" >> _vehicleClass;
private _vehicleName = getText (_vehicleConfig >> "displayName");
if (_vehicleName isEqualTo "") then { _vehicleName = _vehicleClass; };

private _fuelLevel = fuel _vehicle;
private _damage = getDamage _vehicle;

private _fnc_reloadMagazines = {
    params ["_vehicle", "_magazines", "_turretPath"];

    if (_magazines isEqualTo []) exitWith {};

    {
        _vehicle removeMagazineTurret [_x, _turretPath];
    } forEach (_vehicle magazinesTurret _turretPath);

    {
        _vehicle vehicleChat format ["Reloading %1", _x];
        _vehicle addMagazineTurret [_x, _turretPath];
        sleep 0.05;
    } forEach _magazines;
};

private _fnc_reloadTurrets = {
    params ["_vehicle", "_turretsConfig", "_turretPath"];

    for "_i" from 0 to ((count _turretsConfig) - 1) do {
        private _turretConfig = _turretsConfig select _i;

        if (isClass _turretConfig) then {
            private _currentPath = _turretPath + [_i];
            [_vehicle, getArray (_turretConfig >> "magazines"), _currentPath] call _fnc_reloadMagazines;
            [_vehicle, _turretConfig >> "Turrets", _currentPath] call _fnc_reloadTurrets;
        };
    };
};

_vehicle setFuel 0;
_vehicle vehicleChat format ["Servicing %1... Please stand by...", _vehicleName];

[_vehicle, getArray (_vehicleConfig >> "magazines"), [-1]] call _fnc_reloadMagazines;
[_vehicle, _vehicleConfig >> "Turrets", []] call _fnc_reloadTurrets;
_vehicle setVehicleAmmo 1;

_vehicle vehicleChat format ["Repairing and refuelling %1. Stand by...", _vehicleName];

while { alive _vehicle && { _damage > 0 } } do {
    sleep 0.5;
    _damage = (_damage - 0.01) max 0;
    _vehicle setDamage _damage;
    _vehicle vehicleChat format ["Repairing (%1%2)...", floor ((1 - _damage) * 100), "%"];
};

if (alive _vehicle) then {
    _vehicle setDamage 0;
    _vehicle vehicleChat "Repaired (100%).";
};

while { alive _vehicle && { _fuelLevel < 1 } } do {
    sleep 0.5;
    _fuelLevel = (_fuelLevel + 0.01) min 1;
    _vehicle setFuel _fuelLevel;
    _vehicle vehicleChat format ["Refuelling (%1%2)...", floor (_fuelLevel * 100), "%"];
};

if (alive _vehicle) then {
    _vehicle setFuel 1;
    _vehicle vehicleChat "Refuelled (100%).";
    sleep 2;
    _vehicle vehicleChat format ["%1 successfully rearmed, repaired and refuelled.", _vehicleName];
};

_vehicle setVariable ["AB_serviceInProgress", false, true];
