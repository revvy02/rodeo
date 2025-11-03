export type Rev<T> = {
    next: (self: Rev<T>) -> T?,
    collect: (self: Rev<T>) -> { T },
    rev: (self: Rev<T>) -> Rev<T>,
    -- DoubleEndedIterator
    nextBack: (self: Rev<T>) -> T?,

    clone: (self: Rev<T>) -> Rev<T>,
}

type DoubleEndedIterator<T> = {
    next: (self: DoubleEndedIterator<T>) -> T?,
    nextBack: (self: DoubleEndedIterator<T>) -> T?,

    clone: (self: DoubleEndedIterator<T>) -> DoubleEndedIterator<T>,
}

type Private<T> = {
    _iter: DoubleEndedIterator<T>,
}
type PrivateRev<T> = Rev<T> & Private<T>

type RevStatic = {
    new: <T>(iter: DoubleEndedIterator<T>) -> Rev<T>,

    next: <T>(self: Rev<T>) -> T?,
    collect: <T>(self: Rev<T>) -> { T },
    rev: <T>(self: Rev<T>) -> Rev<T>,
    -- DoubleEndedIterator
    nextBack: <T>(self: Rev<T>) -> T?,

    clone: <T>(self: Rev<T>) -> Rev<T>,
}

return nil
