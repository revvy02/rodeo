local function reduce<T, A>(
    array: { T },
    reducer: (accumulator: A, value: T, index: number) -> A,
    accumulator: A?
): A
    if accumulator == nil then
        for index, value in array do
            if index == 1 then
                accumulator = value :: any
            else
                accumulator = reducer(accumulator :: A, value, index)
            end
        end
    else
        for index, value in array do
            accumulator = reducer(accumulator, value, index)
        end
    end
    return accumulator :: A
end

type reduceFromFirstValue = <T>(
    array: { T },
    reducer: (accumulator: T, value: T, index: number) -> T
) -> T?
type reduceWithAccumulator = <T, A>(
    array: { T },
    reducer: (accumulator: A, value: T, index: number) -> A,
    accumulator: A
) -> A

return (reduce :: any) :: reduceFromFirstValue & reduceWithAccumulator
