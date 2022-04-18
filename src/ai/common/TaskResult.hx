package ai.common;

@:enum
abstract TaskResult(Int) from Int to Int {
    var Running = 0;
    var Completed = 1;
    var Failed = 2;
}