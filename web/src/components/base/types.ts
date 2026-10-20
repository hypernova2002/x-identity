export interface SelectOption<V extends string = string> {
  label: string
  value: V
}

export interface TableColumn {
  key: string
  label: string
  srOnly?: boolean
}
