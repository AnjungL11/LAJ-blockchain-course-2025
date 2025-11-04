import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  // solidity: "0.8.20",
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200  // 可以设置为 200-500 之间的值
      }
    }
  },
  networks: {
    ganache: {
      // rpc url, change it according to your ganache configuration
      url: 'http://127.0.0.1:8545',
      // the private key of signers, change it according to your ganache user
      accounts: [
        '0xd73d17294e662076e2efe922de0a636d25fb6f5fb75448f5cd12833cb38138cb',
        '0xb656d94978e71b110f9884ca3896654e768f6f7b0a63f73d147131f3cc855b44',
        '0x7ef4979799efc67f9c539734365d2a196a00e05998e2d9ae4f538cf66c6ff3ae',
        '0x4f5eba9f3209b77eced34c0be4ff788204763729bb1a79f4dfc95678b89125f5',
        '0xba2703cdea3b828f163cee154aaae5a459850261f0305b82c2bccfc25048828d',
        '0x279134ff5d2c5e9e482ba62bb4787b2b3b4ddabac13b964bc3ef74958b2de9d8',
        '0xc86bc00f8076f4854469dfd2bdf3b80554b007d31a34257ed63356efdc674404',
        '0x717b1007a8d3d6fe66f287318d5830446872f423bd5598fde8dad504d16e96dc',
        '0x9fd9d8d58043e40c44ababf116e5fd1cbd0a813f46f18714357301c69326b4c9',
        '0x81822c431a965de4ea64a6af7fdfb33fbb47bdba9a636389976c6a5da6471139'
      ]
    },
  },
};

export default config;
