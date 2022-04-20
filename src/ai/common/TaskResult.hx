package ai.common;

@:enum
@:forward
abstract TaskResult(Int) from Int to Int {
    var Failed = 0;
    var Running = 1;
    var Completed = 2;

    public inline function asInt() : Int {
        return this;
    }
}