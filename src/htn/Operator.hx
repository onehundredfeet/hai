package htn;

@:enum
abstract OperatorResult(Int) from Int to Int {
    var Running = 0;
    var Completed = 1;
    var Failed = 2;
}