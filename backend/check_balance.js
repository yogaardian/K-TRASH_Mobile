const db = require('./src/db');

(async () => {
  try {
    const [rows] = await db.query(
      'SELECT id, nama, email, saldo, saldo_hold FROM users WHERE email = ?',
      ['user@test.com']
    );
    
    if (rows.length > 0) {
      console.log('User found:');
      console.log(`  ID: ${rows[0].id}`);
      console.log(`  Name: ${rows[0].nama}`);
      console.log(`  Email: ${rows[0].email}`);
      console.log(`  Saldo: ${rows[0].saldo}`);
      console.log(`  Saldo Hold: ${rows[0].saldo_hold}`);
    } else {
      console.log('User not found');
    }
    
    process.exit(0);
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
})();
