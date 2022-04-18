package ai.htn;

@:enum abstract BranchState(Int) from Int to Int {
    var None = 0;
    var Expanding = 1;
    var Paused = 2;
    var Success = 3;
    var Failed = 4;
    var Incomplete = 5;
}