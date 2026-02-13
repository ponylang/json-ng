type JsonToken is
  ( JsonTokenNull
  | JsonTokenTrue
  | JsonTokenFalse
  | JsonTokenNumber
  | JsonTokenString
  | JsonTokenKey
  | JsonTokenObjectStart
  | JsonTokenObjectEnd
  | JsonTokenArrayStart
  | JsonTokenArrayEnd
  )

primitive JsonTokenNull
primitive JsonTokenTrue
primitive JsonTokenFalse
primitive JsonTokenNumber
  """After this token, parser.last_number holds the (I64 | F64) value."""
primitive JsonTokenString
  """After this token, parser.last_string holds the string value."""
primitive JsonTokenKey
  """After this token, parser.last_string holds the key name."""
primitive JsonTokenObjectStart
primitive JsonTokenObjectEnd
primitive JsonTokenArrayStart
primitive JsonTokenArrayEnd
