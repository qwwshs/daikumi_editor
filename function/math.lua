function addFractions(num1, denom1, num2, denom2)  --分数相加
    -- 计算新分子和新分母  
    local newNumerator = num1 * denom2 + num2 * denom1  
    local newDenominator = denom1 * denom2  

    -- 约分  
    local function gcd(a, b)  
        while b ~= 0 do  
            a, b = b, a % b  
        end  
        return a  
    end  
    
    local divisor = gcd(math.abs(newNumerator), math.abs(newDenominator))  
    newNumerator = newNumerator / divisor  
    newDenominator = newDenominator / divisor  

    return newNumerator, newDenominator  
end  