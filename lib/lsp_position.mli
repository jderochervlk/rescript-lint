type encoding = Utf8 | Utf16
type position = { line : int; character : int }
type range = { start : position; finish : position }

type error =
  | Offset_out_of_bounds of { byte_offset : int; text_length : int }
  | Offset_not_on_character_boundary of { byte_offset : int }
  | Invalid_utf8 of { byte_offset : int }
  | Invalid_range of { start_offset : int; finish_offset : int }

type t

val create : string -> t
val text : t -> string

val position :
  t -> encoding:encoding -> byte_offset:int -> (position, error) result

val range :
  t ->
  encoding:encoding ->
  start_offset:int ->
  finish_offset:int ->
  (range, error) result

val render_error : error -> string
