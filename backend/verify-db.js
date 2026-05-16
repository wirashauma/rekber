const prisma = require('./src/config/prisma');

async function main() {
  console.log('--- Verifying Database Integrity ---');
  
  try {
    // 1. Fetch the latest 5 transactions
    const latestTransactions = await prisma.transaction.findMany({
      take: 5,
      orderBy: { createdAt: 'desc' },
      include: {
        buyer: { select: { email: true, name: true } },
        seller: { select: { email: true, name: true } },
      }
    });

    if (latestTransactions.length === 0) {
      console.log('No transactions found in the database. Run the integration test first.');
    } else {
      console.log(`Found ${latestTransactions.length} recent transactions.`);

      latestTransactions.forEach((tx, idx) => {
        console.log(`\n[Transaction #${idx + 1}]`);
        console.log(`ID: ${tx.id}`);
        console.log(`Status: ${tx.status}`);
        console.log(`Amount: Rp ${tx.amount}`);
        console.log(`Item Description: ${tx.itemDescription}`);
        console.log(`Buyer: ${tx.buyer?.name || 'Unknown'} (${tx.buyer?.email || 'N/A'})`);
        console.log(`Seller: ${tx.seller?.name || 'Unknown'} (${tx.seller?.email || 'N/A'})`);
        console.log(`Created At: ${tx.createdAt}`);
      });
    }
  } catch (err) {
    console.error('Failed to query database:', err.message);
  }
}

main()
  .then(async () => {
    await prisma.$disconnect();
    console.log('\n--- Verification Complete ---');
  })
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });
