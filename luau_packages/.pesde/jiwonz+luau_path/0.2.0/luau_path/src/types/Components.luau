local Component = require("./Component")
local Prefix = require("./Prefix")
local Rev = require("./Rev")

type Component = Component.Component
type Prefix = Prefix.Prefix
type Rev<T> = Rev.Rev<T>

type char = string

export type Components = {
    -- The prefix as it was originally parsed, if any
    prefix: Prefix?,

    prefixLen: (self: Components) -> number,
    prefixVerbatim: (self: Components) -> boolean,
    -- how much of the prefix is left from the point of view of iteration?
    prefixRemaining: (self: Components) -> number,
    -- Given the iteration so far, how much of the pre-State::Body path is left?
    lenBeforeBody: (self: Components) -> number,
    -- is the iteration complete?
    finished: (self: Components) -> boolean,
    isSepByte: (self: Components, b: char) -> boolean,
    -- asPath: (self: Components) -> Path,
    asPathString: (self: Components) -> string,
    hasRoot: (self: Components) -> boolean,
    includeCurDir: (self: Components) -> boolean,
    parseSingleComponent: (self: Components, comp: string) -> Component?,
    parseNextComponent: (self: Components) -> (number, Component?),
    parseNextComponentBack: (self: Components) -> (number, Component?),
    trimLeft: (self: Components) -> (),
    trimRight: (self: Components) -> (),

    -- Iterator
    next: (self: Components) -> Component?,
    collect: (self: Components) -> { Component },
    rev: (self: Components) -> Rev<Component>,
    -- DoubleEndedIterator
    nextBack: (self: Components) -> Component?,

    -- Clone
    clone: (self: Components) -> Components,
    equal: (self: Components, other: Components) -> boolean,
}

type IterComponents = (items: { Component }, index: number?) -> (number?, Component)

type State = 'Prefix' | 'StartDir' | 'Body' | 'Done'

return nil
