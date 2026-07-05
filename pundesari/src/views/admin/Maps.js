// import React, { useState, useEffect } from "react";
// import axios from "axios";

// // react-bootstrap components
// import { Badge, Button, Card, Container, Row, Col, Form, InputGroup, Table } from "react-bootstrap";

// function Maps() {
//   const [confirmationData, setConfirmationData] = useState([]);
//   const [loading, setLoading] = useState(true);
//   const [searchTerm, setSearchTerm] = useState("");

//   useEffect(() => {
//     const fetchPendingOrders = async () => {
//       try {
//         const response = await axios.get('/orders/pending');
//         setConfirmationData(response.data.map(order => ({
//           id: order.id,
//           nama: order.user_name,
//           jenisSampah: order.jenis_sampah,
//           berat: order.total_berat || "-", // Use total_berat from completed orders
//           totalHarga: order.total_harga ? `Rp ${order.total_harga.toLocaleString()}` : "-", // Use total_harga from completed orders
//           status: order.status === "completed" ? "Menunggu Konfirmasi" : "Pending",
//           sampahData: order.sampah_data ? JSON.parse(order.sampah_data) : null
//         })));
//       } catch (error) {
//         console.error('Failed to fetch orders:', error);
//       }
//       setLoading(false);
//     };
//     fetchPendingOrders();
//   }, []);

//   const getStatusBadge = (status) => {
//     if (status === "Pending") {
//       return <Badge bg="warning" text="dark">Pending</Badge>;
//     } else if (status === "Menunggu Konfirmasi") {
//       return <Badge bg="info" text="dark">Menunggu Konfirmasi</Badge>;
//     } else if (status === "Disetujui") {
//       return <Badge bg="success">Disetujui</Badge>;
//     }
//   };

//   return (
//     <>
//       <Container fluid>
//         <Row>
//           <Col md="12">
//             <Card>
//               <Card.Header>
//                 <Card.Title as="h4">Setatus Konfirmasi</Card.Title>
//               </Card.Header>
//               <Card.Body>
//                 <Row className="align-items-center mb-3">
//                   <Col md="12" className="text-right">
//                     <InputGroup className="ml-auto" style={{ maxWidth: "250px" }}>
//                       <Form.Control
//                         placeholder="Cari..."
//                         type="text"
//                         value={searchTerm}
//                         onChange={(e) => setSearchTerm(e.target.value)}
//                       />
//                     </InputGroup>
//                   </Col>
//                 </Row>

//                 <div className="table-responsive">
//                   <Table className="table-hover table-striped">
//                     <thead>
//                       <tr>
//                         <th className="border-0">Nama</th>
//                         <th className="border-0">Jenis Sampah</th>
//                         <th className="border-0">Berat</th>
//                         <th className="border-0">Total Harga</th>
//                         <th className="border-0">Status</th>
//                         <th className="border-0">Aksi</th>
//                       </tr>
//                     </thead>
//                     <tbody>
//                       {loading ? (
//                         <tr><td colSpan="6" className="text-center">Memuat data...</td></tr>
//                       ) : confirmationData.length === 0 ? (
//                         <tr><td colSpan="6" className="text-center">Data Kosong</td></tr>
//                       ) : (
//                         confirmationData.map((data) => (
//                           <tr key={data.id}>
//                             <td>
//                               <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
//                                 <div
//                                   style={{
//                                     width: "32px",
//                                     height: "32px",
//                                     borderRadius: "50%",
//                                     backgroundColor: "#ddd",
//                                     display: "flex",
//                                     alignItems: "center",
//                                     justifyContent: "center",
//                                     color: "#666",
//                                     fontSize: "12px",
//                                     fontWeight: "bold",
//                                   }}
//                                 >
//                                   {data.nama.charAt(0)}
//                                 </div>
//                                 {data.nama}
//                               </div>
//                             </td>
//                             <td>{data.jenisSampah}</td>
//                             <td>{data.berat}</td>
//                             <td>{data.totalHarga}</td>
//                             <td>{getStatusBadge(data.status)}</td>
//                             <td>
//                               {data.status === "Pending" && (
//                                 <>
//                                   <Button variant="success" size="sm" className="mr-2">
//                                     Setujui
//                                   </Button>
//                                   <Button variant="danger" size="sm">
//                                     Tolak
//                                   </Button>
//                                 </>
//                               )}
//                               {data.status === "Menunggu Konfirmasi" && (
//                                 <>
//                                   <Button variant="success" size="sm" className="mr-2">
//                                     Konfirmasi & Bayar
//                                   </Button>
//                                   <Button variant="danger" size="sm">
//                                     Tolak
//                                   </Button>
//                                 </>
//                               )}
//                               {data.status === "Disetujui" && (
//                                 <Button variant="danger" size="sm">
//                                   Tolak
//                                 </Button>
//                               )}
//                             </td>
//                           </tr>
//                         ))
//                       )}
//                     </tbody>
//                   </Table>
//                 </div>

//                 <Row className="align-items-center mt-3">
//                   <Col>
//                     <nav>
//                       <ul className="pagination mb-0">
//                         <li className="page-item"><a className="page-link" href="#">«</a></li>
//                         <li className="page-item"><a className="page-link" href="#">‹</a></li>
//                         <li className="page-item active"><a className="page-link" href="#">1</a></li>
//                         <li className="page-item"><a className="page-link" href="#">2</a></li>
//                         <li className="page-item"><a className="page-link" href="#">3</a></li>
//                         <li className="page-item"><a className="page-link" href="#">8</a></li>
//                         <li className="page-item"><a className="page-link" href="#">9</a></li>
//                         <li className="page-item"><a className="page-link" href="#">›</a></li>
//                         <li className="page-item"><a className="page-link" href="#">»</a></li>
//                       </ul>
//                     </nav>
//                   </Col>
//                   <Col className="text-right">
//                     <p className="mb-0">Menampilkan 1 - 6 dari 27 transaksi</p>
//                   </Col>
//                 </Row>
//               </Card.Body>
//             </Card>
//           </Col>
//         </Row>
//       </Container>
//     </>
//   );
// }

// export default Maps;