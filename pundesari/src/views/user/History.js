import React, { useState, useEffect } from "react";
import { useHistory } from "react-router-dom";
import { Container, Card, Button, Table, Badge } from "react-bootstrap";
import Sidebar from "../../components/Sidebar.jsx";
import "../../css/Dashboard.css";
import "../../css/sidebar.css";
import { dashboardAPI } from "../../services/api";

function History() {
  const history = useHistory();
  const userId = localStorage.getItem("userId");
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchHistory = async () => {
      try {
        const response = await dashboardAPI.getUserOrders(userId);
        setOrders(response.data);
      } catch (err) {
        console.error("Error fetching history:", err);
      } finally {
        setLoading(false);
      }
    };
    fetchHistory();
  }, [userId]);

  const getStatusBadge = (status) => {
    switch (status) {
      case "pending": return <Badge bg="warning">Pending</Badge>;
      case "assigned": return <Badge bg="info">Assigned</Badge>;
      case "dalam_perjalanan": return <Badge bg="primary">Dalam Perjalanan</Badge>;
      case "arrived": return <Badge bg="secondary">Arrived</Badge>;
      case "completed": return <Badge bg="success">Completed</Badge>;
      default: return <Badge bg="light">Unknown</Badge>;
    }
  };

  return (
    <div className="dashboard-layout">
      <Sidebar />
      <main className="dashboard-main">
        <div style={{ backgroundColor: "#F5F5F5", minHeight: "100vh", padding: "20px 0" }}>
          <Container>
            <div className="d-flex align-items-center mb-4">
              <i 
                className="nc-icon nc-minimal-left" 
                style={{ fontSize: "24px", cursor: "pointer", marginRight: "15px" }}
                onClick={() => history.push("/user/dashboard")}
              ></i>
              <h4 style={{ fontWeight: "bold", color: "#333", margin: "0" }}>Riwayat Order</h4>
            </div>

            <Card style={{ borderRadius: "15px", border: "none", boxShadow: "0 5px 10px rgba(0,0,0,0.05)" }}>
              <Card.Body>
                {loading ? (
                  <p className="text-center">Memuat riwayat...</p>
                ) : orders.length === 0 ? (
                  <p className="text-center">Belum ada riwayat order</p>
                ) : (
                  <Table responsive>
                    <thead>
                      <tr>
                        <th>Tanggal</th>
                        <th>Jenis Sampah</th>
                        <th>Status</th>
                        <th>Aksi</th>
                      </tr>
                    </thead>
                    <tbody>
                      {orders.map(order => (
                        <tr key={order.id}>
                          <td>{new Date(order.created_at).toLocaleDateString()}</td>
                          <td>{order.jenis_sampah || "Tidak ada"}</td>
                          <td>{getStatusBadge(order.status)}</td>
                          <td>
                            <Button 
                              variant="outline-primary" 
                              size="sm"
                              onClick={() => alert(`Detail Order #${order.id}\nAlamat: ${order.address}\nCatatan: ${order.catatan || "Tidak ada"}`)}
                            >
                              Detail
                            </Button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </Table>
                )}
              </Card.Body>
            </Card>
          </Container>
        </div>
      </main>
    </div>
  );
}

export default History;
