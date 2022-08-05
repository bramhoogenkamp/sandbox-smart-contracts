import {ethers} from 'hardhat';
import {read} from '../utils/spreadsheet';

// $ yarn mainnet:run scripts/gathering/connected_GenerateInspector.ts > InspectorGumShoe
// This script prepare data for an external contract (0xc653e1b3a971078812a72d11c45ad71e00f3ad1f)
// The function called is send1155ToAddresses() - check the source code => https://etherscan.io/address/0xc653e1b3a971078812a72d11c45ad71e00f3ad1f#code
// This function takes in 4 parameters

//   address[] calldata userAddresses,
//   uint256[] calldata tokenIds,
//   uint256[] calldata amounts,
//   address tokenAddress

// The script takes a list of address from a spreadsheet
// It performs basic verifications on the address
// Then output the parameters to send to the batch transaction contract
// The output is split in batch of 200 elements in order to fit in a block

// invalid address, contract address will be shown in the terminal

async function main() {
  const provider = ethers.provider;
  const AssetAddress = '0xa342f5d851e866e18ff98f351f2c6637f4478db5';

  // pull data from the spreadsheet - you need to setup .google_credentials.json for this to work
  const dataSpreadSheet: Array<string[]> = await read(
    {
      document: '1aSFdWvHpQEQrUu6eRVRNfVan8-OVILS16ft6uowhX5c',
      sheet: 'P2EFestival - Rewards',
    },
    'A1:ZZ1000'
  );

  const addArray: string[] = [];
  const resIdArray: string[] = [];
  const resAmountArray: number[] = [];

  // remove the first item, then the enclosing array (string[][] to string[])
  dataSpreadSheet.shift();
  dataSpreadSheet.map((val) => addArray.push(val[1]));

  const isAddressNotContract = async (address: string) => {
    const result = await provider.getCode(address);
    return result === '0x';
  };

  // remove whitespaces, check address is valid, is not a contract, if it's an ens
  const verifyAddress = async (address: string) => {
    const addressClean: string = address.replace(/\s/g, '');
    if (ethers.utils.isAddress(addressClean)) {
      if (!(await isAddressNotContract(addressClean))) {
        console.error('contract are not eligible:\t', addressClean);
        return false;
      }
      return addressClean;
    } else {
      try {
        const resolvedEns = await provider.resolveName(addressClean);
        if (resolvedEns !== null && address !== '.eth') {
          return resolvedEns;
        }
        console.error('failed to resolve ens:\t\t', addressClean);
        return false;
      } catch (err) {
        // console.error(err);
      }
    }
  };

  // await all ens resolutions
  const script = async () =>
    Promise.all(addArray.map((add) => verifyAddress(add)));

  // output the params split in batch of 200
  const scriptLog = (
    arrayResolvedAddress: Array<string | false | undefined>
  ) => {
    let index = 0;
    const batchSize = 200;
    const length: number = arrayResolvedAddress.length;

    if (length < batchSize) console.log('===> ONE call needed <===\n\n');
    else console.log('===> MULTIPLE call needed <===\n\n');

    while (index <= length) {
      console.log(`
        execute the following on 0xc653e1b3a971078812a72d11c45ad71e00f3ad1f (MultiSender)
        function: send1155ToAddresses
        args:

      - ${arrayResolvedAddress.slice(index, index + batchSize).join(',')}

      - ${resIdArray.slice(index, index + batchSize).join(',')}

      - ${resAmountArray.slice(index, index + batchSize).join(',')}

      - ${AssetAddress}
      \n\n\n`);
      index += batchSize;
    }
  };

  // remove false value and fill the ids and amouts values (ids and amounts are always the same in this case)
  script()
    .then(async (add) => {
      const resAddArray: (string | false | undefined)[] = add.filter(Boolean);
      resAddArray.map((elem, index) => {
        resIdArray.push(dataSpreadSheet[index][2]);
        resAmountArray.push(parseInt(dataSpreadSheet[index][3], 10));
      });
      scriptLog(resAddArray);
    })
    .catch((err) => console.log(err));
}

main().catch((err) => console.error(err));
