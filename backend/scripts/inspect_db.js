const db = require('../src/db');

async function run() {
  try {
    console.log('Connecting to DB...');

    const [drivers] = await db.query("SELECT id, nama, email, role FROM users WHERE role IN ('driver','petugas') ORDER BY id");
    console.log('\nDrivers:');
    drivers.forEach(d => console.log(`- id=${d.id} name=${d.nama || ''} email=${d.email} role=${d.role}`));

    const [[{total}]] = await db.query('SELECT COUNT(*) as total FROM orders');
    console.log(`\nTotal orders: ${total}`);

    const [group] = await db.query('SELECT driver_id, COUNT(*) AS cnt FROM orders GROUP BY driver_id ORDER BY cnt DESC');
    console.log('\nOrders per driver (driver_id -> count):');
    group.forEach(g => console.log(`- ${g.driver_id} -> ${g.cnt}`));

    const [[{unassigned}]] = await db.query('SELECT COUNT(*) as unassigned FROM orders WHERE driver_id IS NULL');
    console.log(`\nUnassigned orders: ${unassigned}`);

    if (drivers.length > 0) {
      for (let i = 0; i < Math.min(drivers.length, 3); i++) {
        const drv = drivers[i];
        const [[{cnt}]] = await db.query('SELECT COUNT(*) as cnt FROM orders WHERE driver_id = ?', [drv.id]);
        console.log(`\nDriver ${drv.email} (id=${drv.id}) has ${cnt} orders. Recent 5:`);
        const [recent] = await db.query(
          `SELECT id, user_id, driver_id, address, status, jenis_sampah, total_berat, total_harga, created_at FROM orders WHERE driver_id = ? ORDER BY created_at DESC LIMIT 5`,
          [drv.id]
        );
        recent.forEach(r => console.log(JSON.stringify(r)));
      }
    } else {
      console.log('\nNo driver accounts found.');
    }

    process.exit(0);
  } catch (err) {
    console.error('Error querying DB:', err);
    process.exit(2);
  }
}

run();
