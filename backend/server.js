require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const logger = require('./logger');

const app = express();
const PORT = process.env.PORT || 4000;
const MONGO_URI = process.env.MONGO_URI || 'mongodb://mongodb:27017/vuelos';
const JWT_SECRET = process.env.JWT_SECRET;\nif (!JWT_SECRET) {\n  throw new Error('JWT_SECRET is required');\n}

app.use(cors());
app.use(express.json());

app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path} - ${req.ip}`);
  next();
});

mongoose.connect(MONGO_URI)
  .then(() => logger.info('Admin conectado a MongoDB (DB: vuelos)'))
  .catch(err => logger.error(`Error MongoDB: ${err.message}`));

const bookingSchema = new mongoose.Schema({
  flightId: String,
  origin: String,
  destination: String,
  date: String,
  airline: String,
  price: Number,
  passenger: { name: String, email: String },
  status: { type: String, default: 'confirmed', enum: ['confirmed', 'cancelled', 'pending'] }
}, { timestamps: true });

const Booking = mongoose.model('Booking', bookingSchema);

const routeSchema = new mongoose.Schema({
  origin: String,
  originCode: String,
  destination: String,
  destinationCode: String,
  duration: String
});

const Route = mongoose.model('Route', routeSchema);

const flightSchema = new mongoose.Schema({
  flightId: { type: String, required: true, unique: true },
  origin: String,
  originCode: String,
  destination: String,
  destinationCode: String,
  departure: String,
  arrival: String,
  duration: String,
  airline: String,
  price: Number,
  seatsTotal: { type: Number, default: 150 },
  seatsAvailable: { type: Number, default: 150 },
  active: { type: Boolean, default: true },
  date: String
}, { timestamps: true });

const Flight = mongoose.model('Flight', flightSchema);

const adminSchema = new mongoose.Schema({
  name: String,
  email: { type: String, required: true, unique: true },
  password: String,
  role: { type: String, default: 'admin', enum: ['admin', 'propietario'] }
}, { timestamps: true });

const Admin = mongoose.model('Admin', adminSchema);

async function seedAdmin() {
  try {
    const email = process.env.ADMIN_EMAIL;
    const password = process.env.ADMIN_PASSWORD;

    if (!email || !password) {
      logger.warn('ADMIN_EMAIL/ADMIN_PASSWORD not configured; skipping seed admin creation');
      return;
    }

    const existing = await Admin.findOne({ email });
    if (!existing) {
      const hashed = await bcrypt.hash(password, 12);
      await Admin.create({ name: 'Demo Administrator', email, password: hashed, role: 'propietario' });
      logger.info('Seed admin created from environment configuration');
    }
  } catch (err) {
    logger.error(`Error seedAdmin: ${err.message}`);
  }
}
mongoose.connection.once('open', seedAdmin);

const authMiddleware = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Token requerido' });
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: 'Token inválido o expirado' });
  }
};

app.post('/auth/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const admin = await Admin.findOne({ email });
    if (!admin) return res.status(401).json({ error: 'Credenciales incorrectas' });
    const valid = await bcrypt.compare(password, admin.password);
    if (!valid) return res.status(401).json({ error: 'Credenciales incorrectas' });
    const token = jwt.sign({ id: admin._id, email: admin.email, role: admin.role }, JWT_SECRET, { expiresIn: '8h' });
    res.json({ token, admin: { id: admin._id, name: admin.name, email: admin.email, role: admin.role } });
  } catch (err) {
    res.status(500).json({ error: 'Error interno' });
  }
});

app.get('/auth/me', authMiddleware, async (req, res) => {
  try {
    const admin = await Admin.findById(req.user.id).select('-password');
    res.json({ admin });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/stats', authMiddleware, async (req, res) => {
  try {
    const totalBookings = await Booking.countDocuments();
    const confirmedBookings = await Booking.countDocuments({ status: 'confirmed' });
    const cancelledBookings = await Booking.countDocuments({ status: 'cancelled' });
    const totalFlights = await Route.countDocuments();

    const revenueAgg = await Booking.aggregate([
      { $match: { status: 'confirmed' } },
      { $group: { _id: null, total: { $sum: '$price' } } }
    ]);
    const totalRevenue = revenueAgg[0]?.total || 0;

    const uniquePassengers = await Booking.distinct('passenger.email');

    const topRoutes = await Booking.aggregate([
      { $group: { _id: { origin: '$origin', destination: '$destination' }, count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 5 }
    ]);

    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);
    const bookingsByMonth = await Booking.aggregate([
      { $match: { createdAt: { $gte: sixMonthsAgo } } },
      { $group: { _id: { $dateToString: { format: '%Y-%m', date: '$createdAt' } }, count: { $sum: 1 }, revenue: { $sum: '$price' } } },
      { $sort: { _id: 1 } }
    ]);

    const byAirline = await Booking.aggregate([
      { $group: { _id: '$airline', count: { $sum: 1 } } },
      { $sort: { count: -1 } }
    ]);

    res.json({
      totalBookings, confirmedBookings, cancelledBookings,
      totalFlights, totalRevenue,
      uniquePassengers: uniquePassengers.length,
      topRoutes, bookingsByMonth, byAirline
    });
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener estadísticas' });
  }
});

app.get('/bookings', authMiddleware, async (req, res) => {
  try {
    const { page = 1, limit = 20, status, search, origin, destination } = req.query;
    const filter = {};
    if (status) filter.status = status;
    if (origin) filter.origin = new RegExp(origin, 'i');
    if (destination) filter.destination = new RegExp(destination, 'i');
    if (search) {
      filter.$or = [
        { 'passenger.name': new RegExp(search, 'i') },
        { 'passenger.email': new RegExp(search, 'i') },
        { flightId: new RegExp(search, 'i') }
      ];
    }
    const total = await Booking.countDocuments(filter);
    const bookings = await Booking.find(filter)
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(Number(limit));
    res.json({ bookings, total, page: Number(page), pages: Math.ceil(total / limit) });
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener reservas' });
  }
});

app.patch('/bookings/:id/status', authMiddleware, async (req, res) => {
  try {
    const { status } = req.body;
    const booking = await Booking.findByIdAndUpdate(req.params.id, { status }, { new: true });
    if (!booking) return res.status(404).json({ error: 'Reserva no encontrada' });
    res.json({ booking });
  } catch (err) {
    res.status(500).json({ error: 'Error al actualizar reserva' });
  }
});

app.delete('/bookings/:id', authMiddleware, async (req, res) => {
  try {
    await Booking.findByIdAndDelete(req.params.id);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: 'Error al eliminar reserva' });
  }
});

app.get('/flights', authMiddleware, async (req, res) => {
  try {
    const routes = await Route.find();
    const formattedFlights = routes.map((r, index) => ({
      _id: r._id,
      flightId: `FL-${r.originCode}-${r.destinationCode}-${index}`,
      origin: r.origin,
      destination: r.destination,
      duration: r.duration,
      airline: 'Aeroméxico',
      price: 2500,
      active: true
    }));
    res.json({ flights: formattedFlights });
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener rutas' });
  }
});

app.post('/flights', authMiddleware, async (req, res) => {
  try {
    const flight = new Flight(req.body);
    await flight.save();
    res.status(201).json({ flight });
  } catch (err) {
    res.status(500).json({ error: 'Error al crear vuelo' });
  }
});

app.put('/flights/:id', authMiddleware, async (req, res) => {
  try {
    const flight = await Flight.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!flight) return res.status(404).json({ error: 'Vuelo no encontrado' });
    res.json({ flight });
  } catch (err) {
    res.status(500).json({ error: 'Error al actualizar vuelo' });
  }
});

app.delete('/flights/:id', authMiddleware, async (req, res) => {
  try {
    const flight = await Flight.findByIdAndDelete(req.params.id);
    if (!flight) return res.status(404).json({ error: 'Vuelo no encontrado' });
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: 'Error al eliminar vuelo' });
  }
});

app.get('/clients', authMiddleware, async (req, res) => {
  try {
    const { search } = req.query;
    const match = {};
    if (search) {
      match.$or = [
        { 'passenger.name': new RegExp(search, 'i') },
        { 'passenger.email': new RegExp(search, 'i') }
      ];
    }
    const clients = await Booking.aggregate([
      { $match: match },
      { $group: {
        _id: '$passenger.email',
        name: { $first: '$passenger.name' },
        email: { $first: '$passenger.email' },
        totalBookings: { $sum: 1 },
        totalSpent: { $sum: '$price' },
        lastBooking: { $max: '$createdAt' },
        routes: { $addToSet: { origin: '$origin', destination: '$destination' } }
      }},
      { $sort: { totalBookings: -1 } }
    ]);
    res.json({ clients });
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener clientes' });
  }
});

app.get('/admins', authMiddleware, async (req, res) => {
  try {
    const admins = await Admin.find().select('-password');
    res.json({ admins });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/admins', authMiddleware, async (req, res) => {
  try {
    const { name, email, password, role } = req.body;
    const hashed = await bcrypt.hash(password, 10);
    const admin = new Admin({ name, email, password: hashed, role });
    await admin.save();
    res.status(201).json({ admin: { id: admin._id, name, email, role } });
  } catch (err) {
    res.status(500).json({ error: 'Error al crear admin' });
  }
});

app.delete('/admins/:id', authMiddleware, async (req, res) => {
  try {
    await Admin.findByIdAndDelete(req.params.id);
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ error: 'Error al eliminar admin' });
  }
});

app.get('/health', (req, res) => res.json({ status: 'ok', service: 'admin', ts: new Date().toISOString() }));

app.listen(PORT, () => logger.info(`Admin API corriendo en puerto ${PORT}`));