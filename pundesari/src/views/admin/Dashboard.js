import React, { useState, useEffect, useRef } from "react";
import { useHistory } from "react-router-dom";
import ChartistGraph from "react-chartist";
// react-bootstrap components
import {
  Card,
  Container,
  Row,
  Col,
  Badge,
  Spinner,
  Alert,
  Button,
} from "react-bootstrap";
import { dashboardAPI, marketplaceAPI } from "../../services/api";

function Dashboard() {
  const history = useHistory();

  // Dashboard Stats
  const [stats, setStats] = useState({
    totalOrders: 0,
    totalPetugas: 0,
    totalSampah: 0,
    riwayat: 0,
  });
  
  // Total Users (all roles)
  const [totalUsers, setTotalUsers] = useState(0);
  
  // Daily Transactions
  const [dailyTransactions, setDailyTransactions] = useState(0);

  // Recent Activities
  const [aktivitas, setAktivitas] = useState([]);
  const [pendingOrders, setPendingOrders] = useState([]);
  const [marketplacePendingCount, setMarketplacePendingCount] = useState(0);
  const [marketplaceNotification, setMarketplaceNotification] = useState(null);
  const marketplacePendingRef = useRef(null);
  const marketplaceTotalOrdersRef = useRef(null);
  
  // Loading & Error States
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  // Fetch all data
  useEffect(() => {
    const fetchAllData = async () => {
      try {
        setIsLoading(true);
        setError(null);

        // Fetch dashboard stats
        const statsRes = await dashboardAPI.getAdminStats();
        setStats(statsRes.data);

        // Fetch total users
        const usersRes = await dashboardAPI.getTotalUsers();
        setTotalUsers(usersRes.data.totalUsers);

        // Fetch daily transactions
        const dailyRes = await dashboardAPI.getDailyTransactions();
        setDailyTransactions(dailyRes.data.dailyTransactions);

        // Fetch recent orders
        const recentRes = await dashboardAPI.getRecentOrders();
        setAktivitas(recentRes.data.slice(0, 5));

        // Fetch pending orders
        const pendingRes = await dashboardAPI.getPendingOrders();
        setPendingOrders(pendingRes.data.slice(0, 5));

        // Fetch marketplace pending orders for admin notification
        const marketplacePendingRes = await marketplaceAPI.getPendingOrders();
        const marketplacePendingCount = marketplacePendingRes.data?.count || marketplacePendingRes.data?.data?.length || 0;
        setMarketplacePendingCount(marketplacePendingCount);

        if (marketplacePendingRef.current === null && marketplacePendingCount > 0) {
          setMarketplaceNotification(`Ada ${marketplacePendingCount} pesanan marketplace baru menunggu admin.`);
        }
        marketplacePendingRef.current = marketplacePendingCount;

        // Fetch all marketplace orders to detect new incoming buyer orders
        const marketplaceOrdersRes = await marketplaceAPI.getAllOrders();
        const marketplaceTotalCount = marketplaceOrdersRes.data?.length || marketplaceOrdersRes.data?.count || 0;

        if (marketplaceTotalOrdersRef.current === null) {
          marketplaceTotalOrdersRef.current = marketplaceTotalCount;
        } else if (marketplaceTotalCount > marketplaceTotalOrdersRef.current) {
          const diff = marketplaceTotalCount - marketplaceTotalOrdersRef.current;
          setMarketplaceNotification(`Ada ${diff} pesanan marketplace baru masuk.`);
          marketplaceTotalOrdersRef.current = marketplaceTotalCount;
        }

        setIsLoading(false);
      } catch (err) {
        console.error("Error fetching dashboard data:", err);
        setError(err.message || "Gagal memuat data dashboard");
        setIsLoading(false);
      }
    };

    fetchAllData();
    
    // Refresh data every 30 seconds
    const interval = setInterval(fetchAllData, 30000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    let timeoutId;

    const scheduleMidnightRefresh = () => {
      const now = new Date();
      const nextMidnight = new Date(now);
      nextMidnight.setHours(24, 0, 0, 0);
      const delay = nextMidnight.getTime() - now.getTime();

      timeoutId = setTimeout(async () => {
        try {
          const dailyRes = await dashboardAPI.getDailyTransactions();
          setDailyTransactions(dailyRes.data.dailyTransactions);
        } catch (err) {
          console.error("Error refreshing daily transactions at midnight:", err);
        }
        scheduleMidnightRefresh();
      }, delay);
    };

    scheduleMidnightRefresh();
    return () => clearTimeout(timeoutId);
  }, []);

  // Helper function for status badge
  const getStatusBadge = (status) => {
    const statusConfig = {
      pending: { bg: "warning", text: "Menunggu" },
      assigned: { bg: "info", text: "Ditugaskan" },
      on_the_way: { bg: "primary", text: "Dalam Perjalanan" },
      arrived: { bg: "secondary", text: "Tiba" },
      completed: { bg: "success", text: "Selesai" },
      approved: { bg: "success", text: "Disetujui" },
      rejected: { bg: "danger", text: "Ditolak" },
    };
    const config = statusConfig[status] || { bg: "secondary", text: status };
    return <Badge bg={config.bg}>{config.text}</Badge>;
  };

  if (isLoading) {
    return (
      <Container fluid className="d-flex justify-content-center align-items-center" style={{ minHeight: "400px" }}>
        <div className="text-center">
          <Spinner animation="border" role="status" variant="primary" />
          <p className="mt-3">Memuat dashboard...</p>
        </div>
      </Container>
    );
  }

  return (
    <>
      <Container fluid>
        {error && (
          <Alert variant="danger" dismissible>
            ⚠️ {error}
          </Alert>
        )}
        {marketplaceNotification && (
          <Alert variant="info" dismissible onClose={() => setMarketplaceNotification(null)}>
            <div className="d-flex justify-content-between align-items-center">
              <div>
                <strong>Notifikasi Marketplace:</strong> {marketplaceNotification}
              </div>
              <Button
                variant="outline-light"
                size="sm"
                onClick={() => {
                  setMarketplaceNotification(null);
                  history.push("/admin/marketplace");
                }}
              >
                Lihat Detail
              </Button>
            </div>
          </Alert>
        )}

        {/* STATS CARDS */}
        <Row>
          <Col lg="3" sm="6" className="mb-3">
            <Card className="card-stats">
              <Card.Body>
                <Row>
                  <Col xs="5">
                    <div className="icon-big text-center icon-warning">
                      <i className="nc-icon nc-chart text-warning"></i>
                    </div>
                  </Col>
                  <Col xs="7">
                    <div className="numbers">
                      <p className="card-category">Order Aktif</p>
                      <Card.Title as="h4">{stats.totalOrders}</Card.Title>
                    </div>
                  </Col>
                </Row>
              </Card.Body>
              <Card.Footer>
                <hr />
                <div className="stats">
                  <i className="fas fa-sync mr-1"></i>
                  Status: pending + assigned
                </div>
              </Card.Footer>
            </Card>
          </Col>

          <Col lg="3" sm="6" className="mb-3">
            <Card className="card-stats">
              <Card.Body>
                <Row>
                  <Col xs="5">
                    <div className="icon-big text-center icon-warning">
                      <i className="nc-icon nc-circle-10 text-info"></i>
                    </div>
                  </Col>
                  <Col xs="7">
                    <div className="numbers">
                      <p className="card-category">Total User</p>
                      <Card.Title as="h4">{totalUsers}</Card.Title>
                    </div>
                  </Col>
                </Row>
              </Card.Body>
              <Card.Footer>
                <hr />
                <div className="stats">
                  <i className="fas fa-users mr-1"></i>
                  Total User
                </div>
              </Card.Footer>
            </Card>
          </Col>

          <Col lg="3" sm="6" className="mb-3">
            <Card className="card-stats">
              <Card.Body>
                <Row>
                  <Col xs="5">
                    <div className="icon-big text-center icon-warning">
                      <i className="nc-icon nc-vector text-danger"></i>
                    </div>
                  </Col>
                  <Col xs="7">
                    <div className="numbers">
                      <p className="card-category">Sampah Selesai</p>
                      <Card.Title as="h4">{stats.totalSampah}</Card.Title>
                    </div>
                  </Col>
                </Row>
              </Card.Body>
              <Card.Footer>
                <hr />
                <div className="stats">
                  <i className="fas fa-check mr-1"></i>
                  Order completed
                </div>
              </Card.Footer>
            </Card>
          </Col>

          <Col lg="3" sm="6" className="mb-3">
            <Card className="card-stats">
              <Card.Body>
                <Row>
                  <Col xs="5">
                    <div className="icon-big text-center icon-warning">
                      <i className="nc-icon nc-money-coins text-warning"></i>
                    </div>
                  </Col>
                  <Col xs="7">
                    <div className="numbers">
                      <p className="card-category">Transaksi Harian</p>
                      <Card.Title as="h4" style={{ fontSize: "1.4rem", lineHeight: 1.2, whiteSpace: "nowrap" }}>
                        Rp {dailyTransactions?.toLocaleString('id-ID') || '0'}
                      </Card.Title>
                    </div>
                  </Col>
                </Row>
              </Card.Body>
              <Card.Footer>
                <hr />
                <div className="stats">
                  <i className="fas fa-clock mr-1"></i>
                  Reset otomatis setiap 00:00
                </div>
              </Card.Footer>
            </Card>
          </Col>
        </Row>

        {/* MAIN CONTENT */}
        <Row className="mt-4">
          {/* Aktivitas Terbaru */}
          <Col md="6">
            <Card>
              <Card.Header>
                <Card.Title as="h4">📊 Aktivitas Terbaru</Card.Title>
                <p className="card-category">5 order terbaru</p>
              </Card.Header>
              <Card.Body>
                {aktivitas.length > 0 ? (
                  <div className="table-responsive">
                    <table className="table table-hover">
                      <thead>
                        <tr>
                          <th>Order</th>
                          <th>Status</th>
                          <th>Waktu</th>
                        </tr>
                      </thead>
                      <tbody>
                        {aktivitas.map((item, idx) => (
                          <tr key={idx}>
                            <td>{item.judul}</td>
                            <td>{getStatusBadge(item.judul.split('-')[1]?.trim())}</td>
                            <td style={{ fontSize: "0.85rem" }}>{item.waktu}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                ) : (
                  <p className="text-muted">Tidak ada aktivitas</p>
                )}
              </Card.Body>
            </Card>
          </Col>

          {/* Pending Orders */}
          <Col md="6">
            <Card>
              <Card.Header>
                <Card.Title as="h4">⏳ Order Menunggu</Card.Title>
                <p className="card-category">Perlu ditugaskan ke petugas</p>
              </Card.Header>
              <Card.Body>
                {pendingOrders.length > 0 ? (
                  <div className="table-responsive">
                    <table className="table table-hover table-sm">
                      <thead>
                        <tr>
                          <th>ID</th>
                          <th>User</th>
                          <th>Jenis Sampah</th>
                        </tr>
                      </thead>
                      <tbody>
                        {pendingOrders.map((order) => (
                          <tr key={order.id}>
                            <td>#{order.id}</td>
                            <td>{order.user_name || "N/A"}</td>
                            <td>{order.jenis_sampah || "Belum dipilih"}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                ) : (
                  <p className="text-muted">Semua order sudah ditugaskan ✓</p>
                )}
              </Card.Body>
            </Card>
          </Col>
        </Row>

        {/* CHART */}
        <Row className="mt-4">
          <Col md="8">
            <Card>
              <Card.Header>
                <Card.Title as="h4">📈 Performa Harian</Card.Title>
                <p className="card-category">Grafik aktivitas K-Trash</p>
              </Card.Header>
              <Card.Body>
                <div className="ct-chart" id="chartHours">
                  <ChartistGraph
                    data={{
                      labels: ["9:00", "12:00", "15:00", "18:00", "21:00", "00:00"],
                      series: [[stats.totalOrders || 2, 5, 3, 10, 4, 1]],
                    }}
                    type="Line"
                    options={{
                      low: 0,
                      high: Math.max(15, (stats.totalOrders || 10) + 5),
                      showArea: false,
                      height: "245px",
                      axisX: { showGrid: false },
                      lineSmooth: true,
                      showLine: true,
                      showPoint: true,
                      fullWidth: true,
                      chartPadding: { right: 50 },
                    }}
                  />
                </div>
              </Card.Body>
              <Card.Footer>
                <div className="legend">
                  <i className="fas fa-circle text-info"></i>
                  Total Order
                </div>
                <hr />
                <div className="stats">
                  <i className="fas fa-history"></i>
                  Update real-time
                </div>
              </Card.Footer>
            </Card>
          </Col>
        </Row>
      </Container>
    </>
  );
}

export default Dashboard;
