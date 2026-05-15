# =============================================================================
# REKBER API - Full Integration Test
# =============================================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  REKBER API - Integration Test Suite" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- Test 1: Register Buyer ---
Write-Host "1. Register Buyer..." -ForegroundColor Yellow
$buyerBody = @{ name = "Buyer Andi"; email = "andi@rekber.id"; password = "Password123" } | ConvertTo-Json
try {
    $buyer = Invoke-RestMethod -Uri "http://localhost:5000/api/auth/register" -Method POST -ContentType "application/json" -Body $buyerBody
    Write-Host "   OK: $($buyer.message)" -ForegroundColor Green
    Write-Host "   ID: $($buyer.data.id)"
} catch {
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    Write-Host "   FAIL: $($reader.ReadToEnd())" -ForegroundColor Red
}

# --- Test 2: Register Seller ---
Write-Host ""
Write-Host "2. Register Seller..." -ForegroundColor Yellow
$sellerBody = @{ name = "Seller Budi"; email = "budi@rekber.id"; password = "Password123" } | ConvertTo-Json
try {
    $seller = Invoke-RestMethod -Uri "http://localhost:5000/api/auth/register" -Method POST -ContentType "application/json" -Body $sellerBody
    Write-Host "   OK: $($seller.message)" -ForegroundColor Green
    $sellerId = $seller.data.id
    Write-Host "   Seller ID: $sellerId"
} catch {
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    Write-Host "   FAIL: $($reader.ReadToEnd())" -ForegroundColor Red
}

# --- Test 3: Login as Buyer ---
Write-Host ""
Write-Host "3. Login as Buyer..." -ForegroundColor Yellow
$loginBody = @{ email = "andi@rekber.id"; password = "Password123" } | ConvertTo-Json
try {
    $login = Invoke-RestMethod -Uri "http://localhost:5000/api/auth/login" -Method POST -ContentType "application/json" -Body $loginBody
    Write-Host "   OK: $($login.message)" -ForegroundColor Green
    $token = $login.data.token
    Write-Host "   Token: $($token.Substring(0, 30))..."
    $buyerId = $login.data.user.id
    Write-Host "   Buyer ID: $buyerId"
    Write-Host "   Balance: $($login.data.user.balance)"
} catch {
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    Write-Host "   FAIL: $($reader.ReadToEnd())" -ForegroundColor Red
}

# --- Test 4: Create Escrow Transaction ---
Write-Host ""
Write-Host "4. Create Escrow Transaction..." -ForegroundColor Yellow
$txBody = @{ sellerId = $sellerId; amount = 500000; itemDescription = "iPhone 15 Pro Max 256GB" } | ConvertTo-Json
$headers = @{ Authorization = "Bearer $token" }
try {
    $tx = Invoke-RestMethod -Uri "http://localhost:5000/api/transactions" -Method POST -ContentType "application/json" -Body $txBody -Headers $headers
    Write-Host "   OK: $($tx.message)" -ForegroundColor Green
    $txId = $tx.data.id
    Write-Host "   Transaction ID: $txId"
    Write-Host "   Status: $($tx.data.status)"
    Write-Host "   Amount: Rp $($tx.data.amount)"
    Write-Host "   Buyer: $($tx.data.buyer.name) -> Seller: $($tx.data.seller.name)"
} catch {
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    Write-Host "   FAIL: $($reader.ReadToEnd())" -ForegroundColor Red
}

# --- Test 5: Get Transaction Details ---
Write-Host ""
Write-Host "5. Get Transaction Details..." -ForegroundColor Yellow
try {
    $detail = Invoke-RestMethod -Uri "http://localhost:5000/api/transactions/$txId" -Method GET -Headers $headers
    Write-Host "   OK: $($detail.message)" -ForegroundColor Green
    Write-Host "   Status: $($detail.data.status) | Item: $($detail.data.itemDescription)"
} catch {
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    Write-Host "   FAIL: $($reader.ReadToEnd())" -ForegroundColor Red
}

# --- Test 6: Validation Error Test ---
Write-Host ""
Write-Host "6. Test Validation (bad email)..." -ForegroundColor Yellow
$badBody = @{ name = "X"; email = "not-an-email"; password = "short" } | ConvertTo-Json
try {
    Invoke-RestMethod -Uri "http://localhost:5000/api/auth/register" -Method POST -ContentType "application/json" -Body $badBody
} catch {
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    $errorMsg = $reader.ReadToEnd() | ConvertFrom-Json
    Write-Host "   OK (expected error): $($errorMsg.message)" -ForegroundColor Green
    Write-Host "   Errors: $($errorMsg.errors | ConvertTo-Json -Compress)"
}

# --- Test 7: Unauthorized Access Test ---
Write-Host ""
Write-Host "7. Test Unauthorized Access (no token)..." -ForegroundColor Yellow
try {
    Invoke-RestMethod -Uri "http://localhost:5000/api/transactions" -Method POST -ContentType "application/json" -Body "{}"
} catch {
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    $errorMsg = $reader.ReadToEnd() | ConvertFrom-Json
    Write-Host "   OK (expected 401): $($errorMsg.message)" -ForegroundColor Green
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  All tests completed!" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
