var ICOViewo = artifacts.require("./ICOViewo.sol");

module.exports = function(deployer, network) {
    if(network !== 'development'){
        deployer.deploy(ICOViewo).then(async ()=> {
            let Sale = await ICOViewo.deployed();
            console.log(Sale.address);
        })
    }
};