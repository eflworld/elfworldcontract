// SPDX-License-Identifier: Unlicensed
pragma solidity 0.7.6;
pragma abicoder v2;
import "./lib/owner.sol";
import "./lib/address.sol";
import "./lib/SafeMath.sol";
import "./lib/erc.sol";
import "./lib/swap.sol";
contract ELFTToken is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;
  
    mapping (address=> address) private _relations;
	mapping (address => uint256) private _balance;
    mapping (address => mapping (address => uint256)) private _allowances;
    
    mapping (address => bool) private _isExcludedFromFee;
    
    mapping(address => bool) public allowMintAddress;

	address public swapAddr;
	
    uint256 private _total     = 100 * 10**6 * 10**18;
    uint256 private _burnTotal = 79 *  10**6 * 10**18;
	uint256 private _gameRewardRate = 70;    // game reward rate 70%
    uint256 private _tFeeTotal;

    string private _name = "ELFT Token";
    string private _symbol = "ELFT";
    uint8  private _decimals = 18;
    
    address public teamAddr;          // team address 
    uint256 public startReleaseTeamBlocknum;//start release Team coin blocknum
    address public invetAddr;         //invet address
    uint256 public startReleaseInvetBlocknum;//start release invet coin blocknum
    address public marOperaAddr;      //marketing operation address
	uint256 public startReleaseMarketBlocknum;//start release marketing coin blocknum

    uint256 public _releaseTeamLoop;   //team coin release time
	uint256 public _releaseInvetLoop;  //invet coin release time
	uint256 public _releaseMarketLoop;  //Marketing coin release time
	
    uint256 public _everyMonthBlocknum = 864000;
    //uint256 public _everyMonthBlocknum = 40;

    uint256 public _taxFee  = 2;
    uint256 private _previousTaxFee = _taxFee;
    
    uint256 public _liquidityFee = 2;
    uint256 private _previousLiquidityFee = _liquidityFee;
	
    uint256 public _communityFee = 2;
    uint256 private _previousCommunityFee = _communityFee;
	
	uint256 public startBlocknum ;
    uint256 public _releaseAll = 0;
	uint256 public _releaseGroups = 0;
    IMdexRouter public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;
    
    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    
    uint256 public _maxTxAmount=50000000*10**18;
    uint256 private numTokensSellToAddToLiquidity ;

    event ReleaseLog(string,address,uint256,uint256);
    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        address to
    );
    event GetReward(address indexed to, uint256 amount);
    
    
	modifier IsMinter {
        require(allowMintAddress[_msgSender()], "Token:not allow mint");
        _;
    }
    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }
    
    constructor (
        address _initAddr,
		address _swapAddr,
		address _teamAddr,
		address _invetAddr,
		address _marOperaAddr,
		address _consultantAddr,
		uint256 _numLimitSwap
	) {
        uint256 amount          = _total.mul(3).div(100);
		uint256 consultantAmount= _total.mul(2).div(100);
		_releaseGroups          = amount.add(consultantAmount);
        _balance[_initAddr]     = amount;
		_balance[_consultantAddr] = consultantAmount;
        _relations[_initAddr] = _msgSender();
        _relations[_consultantAddr] = _msgSender();
		swapAddr      = _swapAddr;
		invetAddr     = _invetAddr;
		teamAddr      = _teamAddr;
		marOperaAddr  = _marOperaAddr;
		numTokensSellToAddToLiquidity = _numLimitSwap;
        // mainnet
         IMdexRouter _uniswapV2Router = IMdexRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        // testnet
        // IMdexRouter _uniswapV2Router = IMdexRouter(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
        
         // Create a uniswap pair for this new token
        uniswapV2Pair = IMdexFactory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;
        
        //exclude owner and this contract from fee
        _isExcludedFromFee[_initAddr] = true;
        _isExcludedFromFee[address(this)] = true;

		emit Transfer(address(0), _consultantAddr,consultantAmount);
        emit Transfer(address(0), _initAddr, amount);
    }
    function releaseTeam() public  {
        require(startReleaseTeamBlocknum>0,"not set release block");
        require(block.number>startReleaseTeamBlocknum.add(1728000),"not start release");
        uint256 currloop = (block.number.sub(startReleaseTeamBlocknum).sub(1728000)).div(_everyMonthBlocknum)+1;
		if(currloop>40) currloop = 40;
        if(currloop<=_releaseTeamLoop) return ;
        uint256 releaseAmt = 0;
        uint256 amounts    = _total.mul(3).div(1000);
        for(uint256 i = _releaseTeamLoop.add(1);i<=currloop;i++){
            releaseAmt   = releaseAmt.add(amounts);
            emit ReleaseLog("releaseTeam",teamAddr,amounts,i);
            emit Transfer(address(0),teamAddr,amounts);
        }
        if(_relations[teamAddr] ==address(0)){
            _relations[teamAddr] = owner();
        }
		_releaseGroups      = _releaseGroups.add(releaseAmt);
		_releaseTeamLoop    = currloop;
        _balance[teamAddr]  = _balance[teamAddr].add(releaseAmt);
        
    }
	function releaseInvet() public  {
        require(startReleaseInvetBlocknum>0,"not set release block");
        require(block.number>startReleaseInvetBlocknum,"not start release");
        uint256 currloop = (block.number.sub(startReleaseInvetBlocknum)).div(_everyMonthBlocknum)+1;
		if(currloop>5) currloop = 5;
        if(currloop<=_releaseInvetLoop) return ;
        uint256 releaseAmt = 0;
        uint256 amounts    = _total.mul(12).div(1000);
        for(uint256 i = _releaseInvetLoop.add(1);i<=currloop;i++){
            releaseAmt   = releaseAmt.add(amounts);
            emit ReleaseLog("releaseInvet",invetAddr,amounts,i);
            emit Transfer(address(0),invetAddr,amounts);
        }
        if(_relations[invetAddr] ==address(0)){
            _relations[invetAddr] = owner();
        }
		_releaseGroups      = _releaseGroups.add(releaseAmt);
		_releaseInvetLoop    = currloop;
        _balance[invetAddr]  = _balance[invetAddr].add(releaseAmt);
    }
    function releaseMarket() public {
        require(startReleaseMarketBlocknum>0,"not set release block");
        require(block.number>startReleaseMarketBlocknum,"not start release");
        uint256 currloop = (block.number.sub(startReleaseMarketBlocknum)).div(_everyMonthBlocknum)+1;
		if(currloop>7) currloop = 7;
        if(currloop<=_releaseMarketLoop) return ;
        uint256 releaseAmt = 0;
        uint256 amounts    = _total.mul(1).div(100);
        for(uint256 i = _releaseMarketLoop.add(1);i<=currloop;i++){
            releaseAmt   = releaseAmt.add(amounts);
            emit ReleaseLog("releaseMarket",marOperaAddr,amounts,i);
            emit Transfer(address(0),marOperaAddr,amounts);
        }
        if(_relations[marOperaAddr] == address(0)){
            _relations[marOperaAddr] = owner();
        }
		_releaseGroups        = _releaseGroups.add(releaseAmt);
		_releaseMarketLoop    = currloop;
        _balance[marOperaAddr]= _balance[marOperaAddr].add(releaseAmt);
    }
    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _total;
    }
    function totalCirculated() public view returns(uint256){
	    return _releaseAll.add(_releaseGroups).sub(getBurnTotal());
	}
    function balanceOf(address account) public view override returns (uint256) {
        return _balance[account];
    }
    function getBurnTotal() public view returns(uint256){
        return _tFeeTotal.add(_balance[0x000000000000000000000000000000000000dEaD]);
    }
    
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee,bool allFee) private {
        if(!allFee){
           removeAllFee();
           _transferStandard(sender, recipient, amount);
        }else{
           if(!takeFee){
              removeTaxandLiquFee();
           }
           _transferStandard(sender, recipient, amount);
           if(!takeFee){
               restoreTaxAndLiqFee();
           }
        }
        if(!allFee)
            restoreAllFee();

    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 tTransferAmount, uint256 tFee, uint256 tLiquidity,uint256 relationFee) = _getValues(tAmount);
        _balance[sender]    = _balance[sender].sub(tAmount);
        _balance[recipient] = _balance[recipient].add(tTransferAmount);
        _handerRelation(sender,recipient);
        _takeLiquidity(tLiquidity);
        _handerCommityFee(sender,relationFee);
        _reflectFee(tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
    
    function _handerCommityFee(address sender,uint256 amount) private {
        (address oneAddr,address twoAddr) = getRelation(sender);
        if(oneAddr != address(0)&&amount>0){
            _balance[oneAddr] = _balance[oneAddr].add(amount.mul(50).div(100));
            emit Transfer(sender, oneAddr, amount.mul(50).div(100));
        }
        if(twoAddr != address(0)&&amount>0){
            _balance[twoAddr] = _balance[twoAddr].add(amount.mul(50).div(100));
            emit Transfer(sender, twoAddr, amount.mul(50).div(100));
        }
    }
    
    function _handerRelation(address from ,address to) private {
        if(_relations[to]==address(0)){
           _relations[to] = from;
        }
    }
    function getRelation(address addr) public view returns(address,address){
        require(addr !=address(0),"address is zero");
        address oneAddr = _relations[addr];
        address twoAddr = address(0);
        if(oneAddr!=address(0)){
            twoAddr     =  _relations[oneAddr];
        }
        return (oneAddr,twoAddr);
    }
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }
   
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function totalFeeBurn() public view returns (uint256) {
        return _tFeeTotal;
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }
	
    function excludeFromFeeBatch(address[] memory accounts) public onlyOwner {
        require(accounts.length<=20,"data array is to long");
		for (uint8 i = 0; i < accounts.length; i++) {
            excludeFromFee(accounts[i]);
        }
    }
	
    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }
	
	function includeInFeeBatch(address[] memory accounts) public onlyOwner {
        require(accounts.length<=20,"data array is to long");
		for (uint8 i = 0; i < accounts.length; i++) {
            includeInFee(accounts[i]);
        }
    }
    
    function setMinterAddress(address addr, bool isMinter) public onlyOwner {
        allowMintAddress[addr] = isMinter;
    }
    function setStartReleaseTeamBlocknum(uint256 blocknum) public onlyOwner {
        require(startReleaseTeamBlocknum == 0,"token:had set data");
        require(blocknum>=block.number,"token:blocknum is error");
        startReleaseTeamBlocknum = blocknum;
    }
    function setStartReleaseInvetBlocknum(uint256 blocknum) public onlyOwner {
        require(startReleaseInvetBlocknum == 0,"token:had set data");
        require(blocknum>=block.number,"data is error");
        startReleaseInvetBlocknum = blocknum;
    }
    function setStartReleaseMarketBlocknum(uint256 blocknum) public onlyOwner {
        require(startReleaseMarketBlocknum == 0,"token:had set data");
        require(blocknum>=block.number,"token:data is error");
        startReleaseMarketBlocknum = blocknum;
    }

    function setMinterAddressBatch(address[] memory addrs, bool[] memory isMinters) external onlyOwner {
        require(addrs.length <= 20 && addrs.length == isMinters.length, 'length error');
        for (uint8 i = 0; i < addrs.length; i++) {
            setMinterAddress(addrs[i], isMinters[i]);
        }
    }
    
    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }
    
     //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    function _reflectFee(uint256 tFee) private {
		if(tFee>0){
		   _tFeeTotal = _tFeeTotal.add(tFee);
		   //emit Transfer(_msgSender(),address(0),tFee);
		}
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256,uint256) {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 communityFee = calculateCommunityFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity).sub(communityFee);
        return (tTransferAmount, tFee, tLiquidity,communityFee);
    }

    function _takeLiquidity(uint256 tLiquidity) private {       
        _balance[address(this)] = _balance[address(this)].add(tLiquidity);
    }
    
    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(
            10**2
        );
    }
    function calculateLiquidityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_liquidityFee).div(
            10**2
        );
    }
	function calculateCommunityFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_communityFee).div(
            10**2
        );
    }
    
    function removeAllFee() private {
        if(_taxFee == 0 && _liquidityFee == 0&& _communityFee ==0) return;
        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        _previousCommunityFee = _communityFee;
        _taxFee = 0;
        _liquidityFee = 0;
		_communityFee = 0;
    }
    function removeTaxandLiquFee() private {
        if(_taxFee == 0 && _liquidityFee == 0) return;
        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;
        _taxFee = 0;
        _liquidityFee = 0;
    }
    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
		_communityFee = _previousCommunityFee;
    }
    function restoreTaxAndLiqFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
    }
    
    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        if(from != owner() && to != owner())
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));
        
        if(contractTokenBalance >= _maxTxAmount)
        {
            contractTokenBalance = _maxTxAmount;
        }
        
        bool overMinTokenBalance = contractTokenBalance >= numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = numTokensSellToAddToLiquidity;
            //add liquidity
            swapAndLiquify(contractTokenBalance);
        }
        
        //indicates if fee should be deducted from transfer
        bool allFee = true;
        bool takeFee = true;
        uint256 burnTotal = getBurnTotal();
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]){
            allFee = false;
        }
        if(burnTotal>=_burnTotal){
            takeFee = false;
        }
        
        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from,to,amount,takeFee,allFee);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        // uint256 half = contractTokenBalance.div(2);
        // uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        // uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(contractTokenBalance); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        // uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        // addLiquidity(otherHalf, newBalance);
        
        emit SwapAndLiquify(contractTokenBalance, swapAddr);
    }
    
    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        
        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            swapAddr, // receive ETH address
            block.timestamp
        );
    }
    
    function getRewardRate() private view returns(uint256){
	    require(_gameRewardRate<100,"Token:gameRewardrate error");
        return _gameRewardRate;
    }


    function getReward(address to, uint256 amount) external IsMinter returns(bool){
        require(to!=address(0),"Token:address is zero");
        require(amount>0,"Token:amount must be greater 0");
        uint256 amt = _mint(to,amount);
        emit GetReward(to, amt);
        return true;
    }
    function _mint(address addr, uint256 amount) internal returns (uint256){
        uint256 ratePool = getRewardRate();
        require(_releaseAll<_total.mul(ratePool).div(100),"token:out of limit reward amount");
		uint256 leftAmt  = _total.mul(ratePool).div(100).sub(_releaseAll, 'release all sub');
		if(_releaseAll.add(amount)>_total.mul(ratePool).div(100)&&leftAmt>0){
		    amount = leftAmt;
		}
        _releaseAll         = _releaseAll.add(amount);
        _balance[addr]      = _balance[addr].add(amount);
        emit Transfer(address(0),addr,amount);
        return amount;
    }
    function transferBatch(address[] memory  recipientArr, uint256[] memory amountArr) external IsMinter returns (bool) {
	    require(recipientArr.length<=100,"token:data length too long");
	    require(recipientArr.length == amountArr.length,"token:data length not equal");
		for(uint256 i=0;i<recipientArr.length;i++){
		   _transfer(_msgSender(), recipientArr[i], amountArr[i]);
		}
        return true;
    }
}