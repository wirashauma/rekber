// =============================================================================
// Auth Controller
// =============================================================================
// Handles HTTP request/response for authentication and session endpoints.
// Delegates business logic to auth.service.js.

const authService = require('../services/auth.service');

const register = async (req, res, next) => {
  try {
    const { name, email, password } = req.body;
    const userAgent = req.headers['user-agent'];
    const ip = req.ip;

    const result = await authService.register({ name, email, password, userAgent, ip });

    res.status(201).json({
      success: true,
      message: 'Registrasi berhasil! Silakan login.',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const userAgent = req.headers['user-agent'];
    const ip = req.ip;

    const result = await authService.login({ email, password, userAgent, ip });

    res.status(200).json({
      success: true,
      message: 'Login berhasil!',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

const refresh = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    const userAgent = req.headers['user-agent'];
    const ip = req.ip;

    const result = await authService.refresh({ refreshToken, userAgent, ip });

    res.status(200).json({
      success: true,
      message: 'Token berhasil diperbarui.',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

const logout = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    await authService.logout({ refreshToken });

    res.status(200).json({
      success: true,
      message: 'Logout berhasil.',
    });
  } catch (error) {
    next(error);
  }
};

const logoutAll = async (req, res, next) => {
  try {
    const userId = req.user.id;
    await authService.logoutAll(userId);

    res.status(200).json({
      success: true,
      message: 'Semua sesi berhasil dihentikan.',
    });
  } catch (error) {
    next(error);
  }
};

const changePassword = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { oldPassword, newPassword } = req.body;

    await authService.changePassword(userId, { oldPassword, newPassword });

    res.status(200).json({
      success: true,
      message: 'Password berhasil diperbarui.',
    });
  } catch (error) {
    next(error);
  }
};

const forgotPassword = async (req, res, next) => {
  try {
    const { email } = req.body;
    const message = await authService.forgotPassword({ email });

    res.status(200).json({
      success: true,
      message,
    });
  } catch (error) {
    next(error);
  }
};

const resetPassword = async (req, res, next) => {
  try {
    const { token, newPassword } = req.body;
    await authService.resetPassword({ token, newPassword });

    res.status(200).json({
      success: true,
      message: 'Password berhasil direset. Silakan login kembali.',
    });
  } catch (error) {
    next(error);
  }
};

const forgotEmail = (_req, res) => {
  res.status(410).json({
    success: false,
    message: 'Fitur lupa email sudah tidak didukung demi alasan keamanan.',
    code: 'GONE',
  });
};

const me = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const user = await authService.me(userId);

    res.status(200).json({
      success: true,
      data: user,
    });
  } catch (error) {
    next(error);
  }
};

const updateProfile = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { name } = req.body;

    const user = await authService.updateProfile(userId, { name });

    res.status(200).json({
      success: true,
      message: 'Profil berhasil diperbarui.',
      data: user,
    });
  } catch (error) {
    next(error);
  }
};

const updateFcm = async (req, res, next) => {
  try {
    const { fcmToken } = req.body;
    const userId = req.user.id;

    await authService.updateFcm(userId, fcmToken);

    res.status(200).json({
      success: true,
      message: 'FCM Token berhasil diperbarui.',
    });
  } catch (error) {
    next(error);
  }
};

const searchOpponent = async (req, res, next) => {
  try {
    const currentUserId = req.user.id;
    const { query } = req.query;

    const users = await authService.searchOpponent(currentUserId, query);

    res.status(200).json({
      success: true,
      data: users,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  register,
  login,
  refresh,
  logout,
  logoutAll,
  changePassword,
  forgotPassword,
  resetPassword,
  forgotEmail,
  me,
  updateProfile,
  updateFcm,
  searchOpponent,
};
