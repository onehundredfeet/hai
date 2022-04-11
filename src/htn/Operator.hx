package htn;

@:enum
abstract OperatorResult(Int) from Int to Int {
    var Running = 0;
    var Completed = 1;
    var Failed = 2;
}

@:enum abstract BranchState(Int) from Int to Int {
    var None = 0;
    var Expanding = 1;
    var Paused = 2;
    var Success = 3;
    var Failed = 4;
    var Incomplete = 5;
}