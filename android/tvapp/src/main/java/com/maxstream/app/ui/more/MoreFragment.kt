package com.maxstream.app.ui.more

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.app.AlertDialog
import androidx.leanback.app.BrowseSupportFragment
import androidx.leanback.widget.ArrayObjectAdapter
import androidx.leanback.widget.HeaderItem
import androidx.leanback.widget.ListRow
import androidx.leanback.widget.ListRowPresenter
import androidx.leanback.widget.OnItemViewClickedListener
import androidx.lifecycle.lifecycleScope
import com.maxstream.app.R
import com.maxstream.app.data.local.SessionManager
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.data.repository.UpdateRepository
import com.maxstream.app.ui.presentation.CardPresenter
import com.maxstream.app.ui.splash.SplashActivity
import kotlinx.coroutines.launch

class MoreFragment : BrowseSupportFragment() {
    private lateinit var rowsAdapter: ArrayObjectAdapter

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        rowsAdapter = ArrayObjectAdapter(ListRowPresenter())
        adapter = rowsAdapter
        headersState = HEADERS_HIDDEN
        title = "More"
    }

    override fun onActivityCreated(savedInstanceState: Bundle?) {
        super.onActivityCreated(savedInstanceState)
        buildOptions()
        setOnItemViewClickedListener(OnItemViewClickedListener { _, item, _, _ ->
            if (item is MediaItem) handle(item.title)
        })
    }

    private fun buildOptions() {
        rowsAdapter.clear()
        val options = listOf(
            MediaItem(-1, "option", "Help & Support", "", null, null, "", 0.0, emptyList()),
            MediaItem(-2, "option", "About MaxStream", "", null, null, "", 0.0, emptyList()),
            MediaItem(-3, "option", "Join Community", "", null, null, "", 0.0, emptyList()),
            MediaItem(-4, "option", "Check for Update", "", null, null, "", 0.0, emptyList()),
            MediaItem(-5, "option", "Sign Out", "", null, null, "", 0.0, emptyList()),
        )
        val row = ArrayObjectAdapter(CardPresenter()).apply { addAll(0, options) }
        rowsAdapter.add(ListRow(HeaderItem("Account".hashCode().toLong(), "Account"), row))
    }

    private fun handle(title: String) {
        when (title) {
            "Help & Support" -> showDialog("Help & Support", "Join our community or contact support from the app for help.")
            "About MaxStream" -> showDialog(
                "About MaxStream",
                "MaxStream TV v1.0.0\n\nA modern movie and TV discovery app powered by TMDb. " +
                    "Streaming is handled by a native Kotlin player for reliable playback on Android TV.",
            )
            "Join Community" -> {
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://t.me/maxstream254"))
                startActivity(intent)
            }
            "Check for Update" -> checkForUpdate()
            "Sign Out" -> signOut()
        }
    }

    private fun checkForUpdate() {
        lifecycleScope.launch {
            val info = UpdateRepository.checkForUpdate(requireContext())
            if (info == null) {
                showDialog("Up to date", "You are running the latest MaxStream TV build.")
            } else {
                showDialog("Update available", "MaxStream TV v${info.version} is available.\n\n${info.changelog}")
            }
        }
    }

    private fun signOut() {
        SessionManager.signOut(requireContext())
        val intent = Intent(requireActivity(), SplashActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        startActivity(intent)
        requireActivity().finish()
    }

    private fun showDialog(title: String, message: String) {
        AlertDialog.Builder(requireActivity())
            .setTitle(title)
            .setMessage(message)
            .setPositiveButton(android.R.string.ok, null)
            .show()
    }
}
