package com.maxstream.app.ui.details

import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.ImageView
import android.widget.ProgressBar
import android.widget.Spinner
import android.widget.TextView
import androidx.fragment.app.Fragment
import androidx.lifecycle.ViewModelProvider
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.bumptech.glide.Glide
import com.maxstream.app.R
import com.maxstream.app.data.local.WatchlistRepository
import com.maxstream.app.data.model.MediaItem
import com.maxstream.app.data.model.Source
import com.maxstream.app.data.remote.EpisodeRef
import com.maxstream.app.ui.player.PlayerActivity
import com.maxstream.app.ui.viewmodel.DetailsViewModel

class DetailsFragment : Fragment() {

    companion object {
        private const val ARG_ITEM = "item"
        fun newInstance(item: MediaItem): DetailsFragment =
            DetailsFragment().apply { arguments = Bundle().apply { putBundle(ARG_ITEM, item.toBundle()) } }
    }

    private lateinit var viewModel: DetailsViewModel
    private lateinit var item: MediaItem

    private lateinit var poster: ImageView
    private lateinit var titleView: TextView
    private lateinit var metaView: TextView
    private lateinit var overviewView: TextView
    private lateinit var tvControls: View
    private lateinit var seasonSpinner: Spinner
    private lateinit var episodesLabel: TextView
    private lateinit var episodesList: RecyclerView
    private lateinit var playButton: Button
    private lateinit var watchlistButton: Button
    private lateinit var loading: ProgressBar
    private lateinit var errorView: TextView

    private var selectedSeason = 1
    private var resolving = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        item = MediaItem.fromBundle(arguments?.getBundle(ARG_ITEM)!!)
        viewModel = ViewModelProvider(this, DetailsViewModelFactory(requireActivity().application, item))
            [DetailsViewModel::class.java]
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        val root = inflater.inflate(R.layout.tv_details, container, false)
        poster = root.findViewById(R.id.poster)
        titleView = root.findViewById(R.id.title)
        metaView = root.findViewById(R.id.meta)
        overviewView = root.findViewById(R.id.overview)
        tvControls = root.findViewById(R.id.tvControls)
        seasonSpinner = root.findViewById(R.id.seasonSpinner)
        episodesLabel = root.findViewById(R.id.episodesLabel)
        episodesList = root.findViewById(R.id.episodes)
        playButton = root.findViewById(R.id.playButton)
        watchlistButton = root.findViewById(R.id.watchlistButton)
        loading = root.findViewById(R.id.loading)
        errorView = root.findViewById(R.id.error)
        return root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        titleView.text = item.title
        metaView.text = "${item.releaseDate.take(4)}  •  ${if (item.isMovie) "Movie" else "TV Series"}"
        overviewView.text = item.overview.ifBlank { "No overview available." }
        if (item.posterUrl.isNotBlank()) {
            Glide.with(this).load(item.posterUrl).into(poster)
        }

        watchlistButton.text = if (WatchlistRepository.isIn(requireContext(), item)) "✓ In Watchlist" else "＋ Watchlist"
        watchlistButton.setOnClickListener {
            val added = WatchlistRepository.toggle(requireContext(), item)
            watchlistButton.text = if (added) "✓ In Watchlist" else "＋ Watchlist"
        }

        playButton.setOnClickListener { playDefault() }

        if (item.isMovie) {
            tvControls.visibility = View.GONE
            episodesLabel.visibility = View.GONE
            episodesList.visibility = View.GONE
        } else {
            tvControls.visibility = View.VISIBLE
            episodesLabel.visibility = View.VISIBLE
            episodesList.visibility = View.VISIBLE
            episodesList.layoutManager = LinearLayoutManager(requireContext(), LinearLayoutManager.HORIZONTAL, false)
            setupSeasons()
        }

        observe()
    }

    private fun setupSeasons() {
        viewModel.seasonCount.observe(viewLifecycleOwner) { count ->
            val seasons = (1..count).map { "Season $it" }
            seasonSpinner.adapter = ArrayAdapter(requireContext(), android.R.layout.simple_spinner_item, seasons)
                .apply { setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item) }
            seasonSpinner.setSelection(0)
            seasonSpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(p: AdapterView<*>, v: View?, pos: Int, id: Long) {
                    selectedSeason = pos + 1
                    viewModel.loadEpisodes(selectedSeason)
                }
                override fun onNothingSelected(p: AdapterView<*>) {}
            }
        }
        viewModel.loadEpisodes(selectedSeason)
    }

    private fun observe() {
        viewModel.episodes.observe(viewLifecycleOwner) { episodes ->
            episodesList.adapter = EpisodesAdapter(episodes) { episode ->
                viewModel.resolve(selectedSeason, episode.number)
            }
        }
        viewModel.stream.observe(viewLifecycleOwner) { source ->
            if (source != null && !resolving) launchPlayer(source)
        }
        viewModel.resolving.observe(viewLifecycleOwner) { resolving = it; loading.visibility = if (it) View.VISIBLE else View.GONE }
        viewModel.error.observe(viewLifecycleOwner) { msg ->
            if (!msg.isNullOrBlank()) {
                errorView.text = msg
                errorView.visibility = View.VISIBLE
            } else errorView.visibility = View.GONE
        }
    }

    private fun playDefault() {
        if (item.isMovie) viewModel.resolve()
        else viewModel.resolve(selectedSeason, 1)
    }

    private fun launchPlayer(source: Source) {
        resolving = true
        val intent = Intent(requireActivity(), PlayerActivity::class.java).apply {
            putExtra(PlayerActivity.EXTRA_SOURCE, source.toBundle())
        }
        startActivity(intent)
        viewModel.stream.value = null
        resolving = false
    }

    class EpisodesAdapter(
        private val episodes: List<EpisodeRef>,
        private val onClick: (EpisodeRef) -> Unit,
    ) : RecyclerView.Adapter<EpisodesAdapter.VH>() {
        class VH(val button: Button) : RecyclerView.ViewHolder(button)

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
            val button = Button(parent.context).apply {
                layoutParams = ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                )
                isFocusable = true
                isFocusableInTouchMode = true
            }
            return VH(button)
        }

        override fun onBindViewHolder(holder: VH, position: Int) {
            val ep = episodes[position]
            holder.button.text = "E${ep.number} · ${ep.title}"
            holder.button.setOnClickListener { onClick(ep) }
        }

        override fun getItemCount() = episodes.size
    }
}

class DetailsViewModelFactory(
    private val application: android.app.Application,
    private val item: MediaItem,
) : androidx.lifecycle.AndroidViewModelFactory(application) {
    override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T {
        @Suppress("UNCHECKED_CAST")
        return DetailsViewModel(application, item) as T
    }
}
