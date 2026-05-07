export const nullableDateTransformer = {
  to(value?: Date | null) {
    return value ? value.getTime() : null;
  },
  from(value?: number | null) {
    return typeof value === 'number' ? new Date(value) : null;
  }
};
