type person = {
  id: string,
  name: string,
  active: bool,
  verified: bool,
  hasQuota: bool,
}
type state = {version: int}
type featureResult = {enabled: bool}
type saved = {id: string}

@val external isReady: bool = "isReady"
@val external isEnabled: bool = "isEnabled"
@val external isVisible: bool = "isVisible"
@val external featureEnabled: bool = "featureEnabled"
@val external isAdmin: bool = "isAdmin"
@val external status: [#ready | #blocked] = "status"
@val external currentVersion: int = "currentVersion"
@val external previousVersion: int = "previousVersion"
@val external currentItems: array<int> = "currentItems"
@val external expectedItems: array<int> = "expectedItems"
@val external currentState: state = "currentState"
@val external cachedState: state = "cachedState"
@val external measured: float = "measured"
@val external expected: float = "expected"
@val external tolerance: float = "tolerance"
@val external items: 'a = "items"
@val external user: 'a = "user"
@val external users: array<person> = "users"
@val external parts: array<string> = "parts"
@val external html: string = "html"
@val external externalUrl: string = "externalUrl"
@val external previewUrl: string = "previewUrl"
@val external userId: string = "userId"
@val external label: string = "label"
@val external actual: 'a = "actual"
@val external expectedValue: 'a = "expectedValue"
@val external expression: string = "expression"
@val external permissionsTests: unit => unit = "permissionsTests"
@val external saveUserTest: unit => unit = "saveUserTest"
@val external saveAdminTest: unit => unit = "saveAdminTest"
@val external featureTest: unit => unit = "featureTest"
@val external resetDatabase: unit => unit = "resetDatabase"
@val external resetClock: unit => unit = "resetClock"
@val external cleanup: unit => unit = "cleanup"
@val external setup: unit => unit = "setup"
@val external firstTest: unit => unit = "firstTest"
@val external createUserTest: unit => unit = "createUserTest"
@val external loadUserTest: unit => unit = "loadUserTest"
@val external seedDatabase: unit => promise<unit> = "seedDatabase"

@val external readConfig: unit => int = "readConfig"
@val external openHelp: unit => unit = "openHelp"
@val external submit: unit => unit = "submit"
@val external showHelp: unit => unit = "showHelp"
@val external saveForm: unit => unit = "saveForm"
@val external openMenu: unit => unit = "openMenu"
@val external select: 'a => unit = "select"
@val external fetchCount: unit => promise<int> = "fetchCount"
@val external load: 'a => promise<unit> = "load"
@val external loadUser: 'a => unit = "loadUser"
@val external saveUser: 'a => promise<saved> = "saveUser"
@val external validate: 'a => result<'a, string> = "validate"
@val external save: 'a => result<'b, string> = "save"
@val external normalize: 'a => 'a = "normalize"
@val external group: 'a => 'a = "group"
@val external sort: 'a => 'a = "sort"
@val external summarize: 'a => 'a = "summarize"
@val external render: 'a => 'a = "render"
@val external renderLabel: person => string = "renderLabel"
@val external runFeature: (~enabled: bool) => featureResult = "runFeature"

module Analytics = {
  @val external track: string => unit = "track"
}
module Expression = {
  @val external evaluate: string => int = "evaluate"
}
module Database = {
  module User = {
    @val external find: 'a => 'b = "find"
  }
}
module UserService = {
  @val external find: 'a => 'b = "find"
}
module MetricsStore = {
  @val external record: 'a => unit = "record"
}
module Panel = {
  @react.component
  let make = (~children) => <div> children </div>
}
module ItemList = {
  @react.component
  let make = (~items: array<int>, ~onSelect: int => unit) => <div />
}
