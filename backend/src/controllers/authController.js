import db from '../config/db.js';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';
import fs from 'fs';
dotenv.config();

export const register = async (req, res) => {
  const { name, email, password, region, district, sub_district, sto_name } = req.body;
  const face_image = req.file ? req.file.filename : null;
  const face_image_path = req.file ? req.file.path : null;

  // Helper untuk hapus foto kalau gagal
  const deleteUploadedFile = () => {
    if (face_image_path && fs.existsSync(face_image_path)) {
      fs.unlinkSync(face_image_path);
    }
  };

  try {
    const [existing] = await db.query(
      'SELECT id FROM users WHERE email = ?', [email]
    );
    if (existing.length > 0) {
      deleteUploadedFile();
      return res.status(400).json({ message: 'Email sudah terdaftar' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const [result] = await db.query(
      `INSERT INTO users 
        (name, email, password, face_image, region, district, sub_district, sto_name) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [name, email, hashedPassword, face_image, region, district, sub_district, sto_name]
    );

    return res.status(201).json({
      message: 'Registrasi berhasil',
      user_id: result.insertId,
    });
  } catch (error) {
    deleteUploadedFile();
    console.error('Register error:', error);
    return res.status(500).json({ message: 'Server error' });
  }
};

export const login = async (req, res) => {
  const { email, password } = req.body;

  

  try {
    const [rows] = await db.query(
      'SELECT * FROM users WHERE email = ?', [email]
    );
    if (rows.length === 0) {
      return res.status(401).json({ message: 'Email atau password salah' });
    }

    const user = rows[0];
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ message: 'Email atau password salah' });
    }

    const token = jwt.sign(
      { id: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    return res.status(200).json({
      message: 'Login berhasil',
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        face_image: user.face_image,
      },
    });
  } catch (error) {
    console.error('Login error:', error);
    return res.status(500).json({ message: 'Server error' });
  }
};

export const getProfile = async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT id, name, email, face_image, created_at FROM users WHERE id = ?',
      [req.user.id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ message: 'User tidak ditemukan' });
    }
    return res.status(200).json({ user: rows[0] });
  } catch (error) {
    console.error('Profile error:', error);
    return res.status(500).json({ message: 'Server error' });
  }
};