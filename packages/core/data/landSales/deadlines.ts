const deadlines: { [sector: number]: number } = {
   0: new Date("2100-01-01T00:00:00.000Z").valueOf() / 1000,
   1: new Date("2019-12-19T11:00:00.000Z").valueOf() / 1000,
   2: new Date("2020-02-26T12:00:00.000Z").valueOf() / 1000,
   3: new Date("2020-04-14T13:00:00.000Z").valueOf() / 1000,
   4: new Date("2020-07-09T18:59:00.000Z").valueOf() / 1000,
   5: new Date("2020-07-09T18:59:00.000Z").valueOf() / 1000,
   6: new Date("2020-07-09T18:59:00.000Z").valueOf() / 1000,
   7: new Date("2020-07-09T18:59:00.000Z").valueOf() / 1000,
   8: new Date("2020-07-09T18:59:00.000Z").valueOf() / 1000,
   9: new Date("2020-07-09T18:59:00.000Z").valueOf() / 1000,
  10: new Date("2020-08-18T13:00:00.000Z").valueOf() / 1000,
  11: new Date("2020-09-25T17:00:00.000Z").valueOf() / 1000,
  12: new Date("2020-09-25T17:00:00.000Z").valueOf() / 1000,
  13: new Date("2020-09-25T17:00:00.000Z").valueOf() / 1000,
  14: new Date("2020-09-25T17:00:00.000Z").valueOf() / 1000,
  15: new Date("2020-11-26T13:00:00.000Z").valueOf() / 1000,
  16: new Date("2021-02-17T13:00:00.000Z").valueOf() / 1000,
  17: new Date("2021-03-03T13:00:00.000Z").valueOf() / 1000,
  18: new Date("2021-04-29T13:00:00.000Z").valueOf() / 1000,
  19: new Date("2021-06-10T13:00:00.000Z").valueOf() / 1000,
  20: new Date("2021-07-01T13:00:00.000Z").valueOf() / 1000,
  21: new Date("2021-07-08T13:00:00.000Z").valueOf() / 1000,
  22: new Date("2021-07-15T13:00:00.000Z").valueOf() / 1000,
  23: new Date("2021-07-22T13:00:00.000Z").valueOf() / 1000,
  24: new Date("2021-07-29T13:00:00.000Z").valueOf() / 1000,
  25: new Date("2021-08-12T13:00:00.000Z").valueOf() / 1000,
  26: new Date("2021-08-19T13:00:00.000Z").valueOf() / 1000,
  27: new Date("2021-09-02T13:00:00.000Z").valueOf() / 1000,
  28: new Date("2021-09-09T13:00:00.000Z").valueOf() / 1000,
  29: new Date("2021-09-16T13:00:00.000Z").valueOf() / 1000,
  30: new Date("2021-09-23T13:00:00.000Z").valueOf() / 1000,
  31: new Date("2021-09-30T13:00:00.000Z").valueOf() / 1000,
  32: new Date("2021-11-11T13:00:00.000Z").valueOf() / 1000,
  33: new Date("2021-12-09T13:00:00.000Z").valueOf() / 1000,
  34: new Date("2021-12-23T13:00:00.000Z").valueOf() / 1000,
  35: new Date("2022-03-03T13:00:00.000Z").valueOf() / 1000, // TODO: to be determined
  36: new Date("2022-01-20T13:00:00.000Z").valueOf() / 1000,
  38: new Date("2022-02-17T13:00:00.000Z").valueOf() / 1000,
  39: new Date("2022-03-10T13:00:00.000Z").valueOf() / 1000,
  40: new Date("2022-04-14T13:00:00.000Z").valueOf() / 1000,
  41: new Date("2022-05-05T13:00:00.000Z").valueOf() / 1000,
  42: new Date("2022-11-12T16:00:00.000Z").valueOf() / 1000,
  43: new Date("2022-12-20T12:00:00.000Z").valueOf() / 1000,
  44: new Date("2022-12-20T12:00:00.000Z").valueOf() / 1000,
  45: new Date("2022-12-20T12:00:00.000Z").valueOf() / 1000,
  46: new Date("2023-02-28T13:00:00.000Z").valueOf() / 1000,
  47: new Date("2023-05-25T12:00:00.000Z").valueOf() / 1000,
  48: new Date("2023-06-22T12:00:00.000Z").valueOf() / 1000,
  49: new Date("2023-07-28T12:00:00.000Z").valueOf() / 1000,
  50: new Date("2023-09-04T12:00:00.000Z").valueOf() / 1000,
  51: new Date("2023-10-12T12:00:00.000Z").valueOf() / 1000,
  52: new Date("2023-12-07T12:00:00.000Z").valueOf() / 1000,
  53: new Date("2023-11-14T12:00:00.000Z").valueOf() / 1000,
};
export default deadlines;
